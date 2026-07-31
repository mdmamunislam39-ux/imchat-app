const functions = require("firebase-functions/v1");
const admin = require('firebase-admin');

// We assume admin is initialized in index.js
const db = admin.database();
const firestore = admin.firestore();

const PHASES = {
    BETTING: 'betting',
    SPINNING: 'spinning',
    RESULT: 'result'
};

const DURATION_MS = {
    BETTING: 30000,
    SPINNING: 3000,
    RESULT: 4000,
};

const SYMBOLS = [0, 1, 2, 3, 4, 5, 6, 7, -2, -3];

const MULTIPLIERS = {
    0: 10, 1: 15, 2: 25, 3: 45, // meat
    4: 5, 5: 5, 6: 5, 7: 5   // veg
};

async function generateResult(totalBets) {
    try {
        const configDoc = await firestore.collection('config').doc('pink_greedy_game').get();
        let winningChance = 50;

        if (configDoc.exists) {
            const data = configDoc.data();
            winningChance = typeof data.winningChance === 'number' ? data.winningChance : (data.winRatio ?? 50);
        }

        const bets = totalBets || {};

        // Calculate total bet pool
        let totalBetPool = 0;
        for (let i = 0; i <= 7; i++) {
            totalBetPool += (bets[i] || 0);
        }

        const maxPayout = totalBetPool * (winningChance / 100.0);

        // Calculate potential payout for standard items (0 to 7)
        const payouts = {};
        let minPayout = Infinity;
        let minPayoutOutcome = 0;

        for (let i = 0; i <= 7; i++) {
            payouts[i] = (bets[i] || 0) * MULTIPLIERS[i];
            if (payouts[i] < minPayout) {
                minPayout = payouts[i];
                minPayoutOutcome = i;
            }
        }

        // For Pizza (-2) and Salad (-3), they are special.
        // Let's assume their payout is roughly equivalent to 5x the total bets on their types, 
        // to simplify the probability logic. If they exceed maxPayout, we don't pick them.
        let meatBets = (bets[0] || 0) + (bets[1] || 0) + (bets[2] || 0) + (bets[3] || 0);
        let vegBets = (bets[4] || 0) + (bets[5] || 0) + (bets[6] || 0) + (bets[7] || 0);
        payouts[-2] = meatBets * 5; // Simplified worst-case payout for Pizza
        payouts[-3] = vegBets * 5;  // Simplified worst-case payout for Salad

        if (payouts[-2] < minPayout) { minPayout = payouts[-2]; minPayoutOutcome = -2; }
        if (payouts[-3] < minPayout) { minPayout = payouts[-3]; minPayoutOutcome = -3; }

        const validOutcomes = [];
        for (const symbol of SYMBOLS) {
            if (payouts[symbol] <= maxPayout) {
                validOutcomes.push(symbol);
            }
        }

        if (validOutcomes.length === 0) {
            return minPayoutOutcome;
        }

        // Pick a random valid outcome
        const randomIndex = Math.floor(Math.random() * validOutcomes.length);
        return validOutcomes[randomIndex];

    } catch (error) {
        console.error("Failed to calculate pink greedy game result", error);
        return 0;
    }
}

async function runPinkGreedyTick() {
    const roundRef = db.ref('pink_greedy_game/current_round');

    const result = await roundRef.transaction((currentData) => {
        const now = Date.now();
        const FULL_ROUND_TIME = DURATION_MS.BETTING + DURATION_MS.SPINNING + DURATION_MS.RESULT; // 37000ms

        // Calculate expected deterministic round based on 10 PM BST start time
        const bstOffset = 6 * 60 * 60 * 1000;
        const bstDate = new Date(now + bstOffset);
        let startBst = new Date(bstDate);
        startBst.setUTCHours(22, 0, 0, 0);
        if (bstDate.getUTCHours() < 22) {
            startBst.setUTCDate(startBst.getUTCDate() - 1);
        }
        const startTimeMs = startBst.getTime() - bstOffset;
        const timeSinceStart = now - startTimeMs;
        const currentExpectedRound = Math.floor(timeSinceStart / FULL_ROUND_TIME) + 1;
        const expectedDayId = startBst.toISOString().split('T')[0];
        const currentRoundStartTime = startTimeMs + (currentExpectedRound - 1) * FULL_ROUND_TIME;

        if (!currentData) {
            return {
                roundNumber: currentExpectedRound,
                dailyRoundDate: expectedDayId,
                phase: PHASES.BETTING,
                phaseEndTime: currentRoundStartTime + DURATION_MS.BETTING,
                totalBets: {},
                bets: {},
                result: null,
                winners: {}
            };
        }

        if (now < currentData.phaseEndTime - 2000) return;

        let timePassed = now - currentData.phaseEndTime;
        
        if (timePassed > FULL_ROUND_TIME) {
            currentData.roundNumber = currentExpectedRound;
            currentData.dailyRoundDate = expectedDayId;
            currentData.phase = PHASES.BETTING;
            currentData.phaseEndTime = currentRoundStartTime + DURATION_MS.BETTING;
            currentData.totalBets = {};
            currentData.bets = {};
            currentData.winners = {};
            currentData.result = null;
            return currentData;
        }

        if (currentData.phase === PHASES.BETTING) {
            currentData.phase = PHASES.SPINNING;
            currentData.phaseEndTime = (currentData.phaseEndTime || now) + DURATION_MS.SPINNING;
            currentData.result = 'PENDING';
            return currentData;
        }
        else if (currentData.phase === PHASES.SPINNING) {
            currentData.phase = PHASES.RESULT;
            currentData.phaseEndTime = (currentData.phaseEndTime || now) + DURATION_MS.RESULT;
            return currentData;
        }
        else if (currentData.phase === PHASES.RESULT) {
            return {
                roundNumber: currentExpectedRound,
                dailyRoundDate: expectedDayId,
                phase: PHASES.BETTING,
                phaseEndTime: currentRoundStartTime + DURATION_MS.BETTING,
                totalBets: {},
                bets: {},
                result: null,
                winners: {}
            };
        }
        return;
    }, (error) => {
        if (error) console.error("Pink Greedy Game transaction failed", error);
    });

    if (result.committed) {
        let newData = result.snapshot.val();

        if (newData && newData.phase === PHASES.SPINNING && newData.result === 'PENDING') {
            const newResult = await generateResult(newData.totalBets);
            await roundRef.child('result').set(newResult);
            newData.result = newResult;
        }

        if (newData && newData.phase === PHASES.RESULT) {
            await processPayouts(newData, result.snapshot.ref);
        }

        return { status: 'transitioned', newPhase: newData.phase };
    }
    return { status: 'waiting' };
}
exports.runPinkGreedyTick = runPinkGreedyTick;

exports.tickPinkGreedyGame = functions.https.onCall(async (data, context) => {
    return await runPinkGreedyTick();
});

const EMOJIS = {0: '🌭', 1: '🍢', 2: '🍖', 3: '🥩', 4: '🥕', 5: '🌽', 6: '🥬', 7: '🍅', '-2': '🍕', '-3': '🥗'};

async function processPayouts(roundData, roundRef) {
    if (!roundData.bets || roundData.result === null || roundData.result === 'PENDING') return;

    const resultSymbol = roundData.result;
    const batch = firestore.batch();

    // We need roundDate and roundNumber for history
    const roundNumber = roundData.roundNumber || 0;
    const dailyRoundDate = roundData.dailyRoundDate || new Date().toISOString().split('T')[0];
    const winningEmoji = EMOJIS[resultSymbol] || '❓';
    
    let totalPrizePool = 0;

    for (const [userId, userBet] of Object.entries(roundData.bets)) {
        let prize = 0;
        let totalBetPlaced = 0;

        for (const [sym, amt] of Object.entries(userBet)) {
            totalBetPlaced += amt;
        }

        if (resultSymbol >= 0) {
            if (userBet[resultSymbol]) {
                prize = userBet[resultSymbol] * MULTIPLIERS[resultSymbol];
            }
        } else {
            // Pizza (-2) or Salad (-3)
            const targetType = resultSymbol === -2 ? 'meat' : 'veg';
            let totalBetOnType = 0;
            for (let i = 0; i <= 7; i++) {
                const itemType = (i <= 3) ? 'meat' : 'veg';
                if (itemType === targetType && userBet[i]) {
                    totalBetOnType += userBet[i];
                }
            }
            if (totalBetOnType > 0) {
                prize = totalBetOnType * 5;
            }
        }

        const userWalletRef = firestore.collection('Users').doc(userId);
        const userDoc = await userWalletRef.get();
        const userData = userDoc.data() || {};
        const username = userData.fullname || 'User';
        const profilePic = userData.photoUrl || '';

        if (prize > 0) {
            batch.set(userWalletRef, { diamonds: admin.firestore.FieldValue.increment(prize) }, { merge: true });
            
            const leaderboardRef = firestore.collection('pink_greedy_game_leaderboard')
                .doc('daily')
                .collection(dailyRoundDate)
                .doc(userId);
            batch.set(leaderboardRef, {
                totalWon: admin.firestore.FieldValue.increment(prize),
                username: username,
                profilePic: profilePic,
                lastWin: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
            
            const roundLeaderboardRef = firestore.collection('pink_greedy_game_round_leaderboard')
                .doc(`round_${dailyRoundDate}_${roundNumber}`)
                .collection('users')
                .doc(userId);
            batch.set(roundLeaderboardRef, {
                won: prize,
                username: username,
                profilePic: profilePic
            }, { merge: true });

            totalPrizePool += prize;
        }

        if (totalBetPlaced > 0) {
            const historyRef = firestore.collection('pink_greedy_game_bet_history')
                .doc(userId)
                .collection('history')
                .doc();
            batch.set(historyRef, {
                roundNumber: roundNumber,
                totalBet: totalBetPlaced,
                winAmount: prize,
                winningEmoji: winningEmoji,
                timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }

    if (totalPrizePool > 0) {
        const stateRef = firestore.collection('pink_greedy_game_state').doc(dailyRoundDate);
        batch.set(stateRef, { prizePool: admin.firestore.FieldValue.increment(totalPrizePool) }, { merge: true });
    }

    await batch.commit();
}
exports.placePinkGreedyGameBet = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const { symbol, amount } = data;

    if (symbol === undefined || !amount || amount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid bet data');
    }

    if (!MULTIPLIERS[symbol]) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid symbol');
    }

    const userRef = firestore.collection('Users').doc(uid);
    const roundRef = db.ref('pink_greedy_game/current_round');

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

            const roundSnap = await roundRef.once('value');
            const roundData = roundSnap.val();

            if (!roundData || roundData.phase !== PHASES.BETTING || roundData.phaseEndTime < Date.now()) {
                throw new functions.https.HttpsError('failed-precondition', 'Betting is closed');
            }

            transaction.update(userRef, {
                diamonds: admin.firestore.FieldValue.increment(-amount)
            });
        });

        await roundRef.child(`totalBets/${symbol}`).set(admin.database.ServerValue.increment(amount));
        await roundRef.child(`bets/${uid}/${symbol}`).set(admin.database.ServerValue.increment(amount));

        return { success: true };

    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message || 'Failed to place bet');
    }
});
