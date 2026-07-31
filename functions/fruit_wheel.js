const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');

// Ensure admin is initialized only once, it's done in index.js usually.
const db = admin.database();
const firestore = admin.firestore();

// Game Configuration
const PHASES = {
    BETTING: 'betting',
    SPINNING: 'spinning',
    RESULT: 'result'
};

const DURATION_MS = {
    BETTING: 25000, // 25 seconds for betting
    SPINNING: 6000, // 6 seconds for spinning
    RESULT: 5000,   // 5 seconds to show result
};

const SYMBOLS = {
    WATERMELON: 'watermelon',
    PLUM: 'plum',
    SEVENS: 'sevens'
};

const MULTIPLIERS = {
    [SYMBOLS.WATERMELON]: 2,
    [SYMBOLS.PLUM]: 2,
    [SYMBOLS.SEVENS]: 8
};

// Generate a random result based on controlled probability from Admin Panel
async function generateResult(totalBets) {
    try {
        const configDoc = await firestore.collection('config').doc('fruit_wheel').get();
        let winningChance = 50; // default 50%
        let wWatermelon = 1, wPlum = 1, wSevens = 1;
        
        if (configDoc.exists) {
            const data = configDoc.data();
            winningChance = typeof data.winningChance === 'number' ? data.winningChance : (data.winRatio ?? 50);
            wWatermelon = data.watermelonWeight || 1;
            wPlum = data.grapeWeight || 1;
            wSevens = data.sevensWeight || 1;
        }

        const bets = totalBets || { watermelon: 0, plum: 0, sevens: 0 };
        const totalBetPool = (bets.watermelon || 0) + (bets.plum || 0) + (bets.sevens || 0);
        
        // Allowed maximum payout based on winning chance
        const maxPayout = totalBetPool * (winningChance / 100.0);

        // Calculate potential payout for each outcome
        const payouts = {
            [SYMBOLS.WATERMELON]: (bets.watermelon || 0) * MULTIPLIERS[SYMBOLS.WATERMELON],
            [SYMBOLS.PLUM]: (bets.plum || 0) * MULTIPLIERS[SYMBOLS.PLUM],
            [SYMBOLS.SEVENS]: (bets.sevens || 0) * MULTIPLIERS[SYMBOLS.SEVENS]
        };

        const validOutcomes = [];
        let minPayoutOutcome = SYMBOLS.WATERMELON;
        let minPayout = payouts[SYMBOLS.WATERMELON];

        for (const symbol of [SYMBOLS.WATERMELON, SYMBOLS.PLUM, SYMBOLS.SEVENS]) {
            if (payouts[symbol] <= maxPayout) {
                validOutcomes.push(symbol);
            }
            if (payouts[symbol] < minPayout) {
                minPayout = payouts[symbol];
                minPayoutOutcome = symbol;
            }
        }

        // If no outcomes are within the allowed payout (e.g. users bet heavily on everything), 
        // force the minimum payout outcome.
        if (validOutcomes.length === 0) {
            return minPayoutOutcome;
        }

        // Apply weights to valid outcomes
        let totalValidWeight = 0;
        const validWeights = {};
        for (const symbol of validOutcomes) {
            let weight = 1;
            if (symbol === SYMBOLS.WATERMELON) weight = wWatermelon;
            if (symbol === SYMBOLS.PLUM) weight = wPlum;
            if (symbol === SYMBOLS.SEVENS) weight = wSevens;
            validWeights[symbol] = weight;
            totalValidWeight += weight;
        }

        let rand = Math.random() * totalValidWeight;
        for (const symbol of validOutcomes) {
            if (rand < validWeights[symbol]) return symbol;
            rand -= validWeights[symbol];
        }

        return validOutcomes[0]; // Fallback
    } catch (error) {
        console.error("Failed to read config, using defaults", error);
        // Fallback defaults
        const rand = Math.random() * 100;
        if (rand < 50) return SYMBOLS.WATERMELON;
        if (rand < 90) return SYMBOLS.PLUM;
        return SYMBOLS.SEVENS;
    }
}

// Tick the game to progress phases
async function runFruitWheelTick() {
    const roundRef = db.ref('fruit_wheel/current_round');
    
    // We use a transaction to ensure no concurrent phase transitions happen
    const result = await roundRef.transaction((currentData) => {
        const now = Date.now();
        
        // If no game exists, initialize it
        if (!currentData) {
            return {
                roundNumber: 1,
                phase: PHASES.BETTING,
                phaseEndTime: now + DURATION_MS.BETTING,
                totalBets: { watermelon: 0, plum: 0, sevens: 0 },
                bets: {},
                result: null,
                winners: {}
            };
        }

        // Only transition if the phase time has elapsed
        if (now < currentData.phaseEndTime) {
            return; // abort transaction, no change needed
        }

        // Transition logic
        if (currentData.phase === PHASES.BETTING) {
            // BETTING -> SPINNING
            currentData.phase = PHASES.SPINNING;
            currentData.phaseEndTime = now + DURATION_MS.SPINNING;
            currentData.result = 'PENDING'; // Placeholder, updated outside transaction
            return currentData;
        } 
        else if (currentData.phase === PHASES.SPINNING) {
            // SPINNING -> RESULT
            currentData.phase = PHASES.RESULT;
            currentData.phaseEndTime = now + DURATION_MS.RESULT;
            
            // Winners will be calculated in a separate process/trigger, 
            // but for simplicity we can do it here inside the transaction if it's fast enough
            // NOTE: Doing heavy writes inside RTDB transaction can be slow, 
            // but it's safe for a moderate number of players.
            return currentData;
        }
        else if (currentData.phase === PHASES.RESULT) {
            // RESULT -> BETTING (Next Round)
            const nextRound = {
                roundNumber: (currentData.roundNumber || 0) + 1,
                phase: PHASES.BETTING,
                phaseEndTime: now + DURATION_MS.BETTING,
                totalBets: { watermelon: 0, plum: 0, sevens: 0 },
                bets: {},
                result: null,
                winners: {}
            };
            return nextRound;
        }

        return; // abort
    }, (error, committed, snapshot) => {
        if (error) {
            console.error("Transaction failed abnormally!", error);
        }
    });

    if (result.committed) {
        let newData = result.snapshot.val();
        
        // Async update for result if we just transitioned to SPINNING
        if (newData && newData.phase === PHASES.SPINNING && newData.result === 'PENDING') {
            const newResult = await generateResult(newData.totalBets);
            await roundRef.child('result').set(newResult);
            newData.result = newResult;
        }

        // If we just transitioned to RESULT, we need to process payouts
        if (newData && newData.phase === PHASES.RESULT) {
            await processPayouts(newData, result.snapshot.ref);
            await saveHistory(newData);
        }
        
        return { status: 'transitioned', newPhase: newData.phase };
    }

    return { status: 'waiting' };
}
exports.runFruitWheelTick = runFruitWheelTick;

exports.tickFruitWheelGame = functions.https.onCall(async (data, context) => {
    return await runFruitWheelTick();
});

// Process payouts asynchronously (avoids blocking the RTDB transaction)
async function processPayouts(roundData, roundRef) {
    if (!roundData.bets || !roundData.result) return;
    
    const resultSymbol = roundData.result;
    const multiplier = MULTIPLIERS[resultSymbol] || 0;
    
    const winners = {};
    const batch = firestore.batch();
    
    // Fetch user details for winners to show in RTDB
    for (const [uid, userBets] of Object.entries(roundData.bets)) {
        let totalBet = 0;
        let winAmount = 0;
        
        for (const [symbol, amount] of Object.entries(userBets)) {
            totalBet += amount;
            if (symbol === resultSymbol) {
                winAmount += amount * multiplier;
            }
        }
        
        const netResult = winAmount - totalBet;
        
        if (winAmount > 0) {
            // User won! We need to add diamonds back (bet + winnings)
            // They already paid the bet amount during placeBet, so we add winAmount
            const userRef = firestore.collection('Users').doc(uid);
            batch.update(userRef, {
                diamonds: admin.firestore.FieldValue.increment(winAmount)
            });
            
            // We just record the net profit/payout for the UI
            winners[uid] = {
                payout: winAmount,
                name: "Player", // We could fetch actual names here if needed
                photo: ""
            };
        }
        
        // Save to user's bet history
        const historyRef = firestore.collection('Users').doc(uid).collection('bet_history').doc(`round_${roundData.roundNumber}`);
        batch.set(historyRef, {
            roundNumber: roundData.roundNumber,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            bets: userBets,
            result: resultSymbol,
            netResult: netResult
        });
    }
    
    await batch.commit();
    
    // Update winners in RTDB so clients can see
    if (Object.keys(winners).length > 0) {
        await roundRef.child('winners').set(winners);
    }
}

async function saveHistory(roundData) {
    // Only save essential info to history
    const historyEntry = {
        roundNumber: roundData.roundNumber,
        result: roundData.result,
        timestamp: Date.now()
    };
    await db.ref(`fruit_wheel/history/${roundData.roundNumber}`).set(historyEntry);
}

// Place a bet
exports.placeFruitWheelBet = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    
    const uid = context.auth.uid;
    const { symbol, amount } = data;
    
    if (!symbol || !amount || amount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid bet data');
    }
    
    if (!MULTIPLIERS[symbol]) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid symbol');
    }

    const userRef = firestore.collection('Users').doc(uid);
    const roundRef = db.ref('fruit_wheel/current_round');
    
    try {
        await firestore.runTransaction(async (transaction) => {
            const userDoc = await transaction.get(userRef);
            if (!userDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'User not found');
            }
            
            const diamonds = userDoc.data().diamonds || 0;
            if (diamonds < amount) {
                throw new functions.https.HttpsError('failed-precondition', 'Not enough diamonds');
            }
            
            // Check phase in RTDB using a single read (might be slightly out of sync but safe enough for betting)
            const roundSnap = await roundRef.once('value');
            const roundData = roundSnap.val();
            
            if (!roundData || roundData.phase !== PHASES.BETTING || roundData.phaseEndTime < Date.now()) {
                throw new functions.https.HttpsError('failed-precondition', 'Betting is closed');
            }
            
            // Deduct diamonds
            transaction.update(userRef, {
                diamonds: admin.firestore.FieldValue.increment(-amount)
            });
        });
        
        // Now update RTDB bets
        // Use increment to update total and user bets
        await roundRef.child(`totalBets/${symbol}`).set(admin.database.ServerValue.increment(amount));
        await roundRef.child(`bets/${uid}/${symbol}`).set(admin.database.ServerValue.increment(amount));
        
        return { success: true };
        
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message || 'Failed to place bet');
    }
});
