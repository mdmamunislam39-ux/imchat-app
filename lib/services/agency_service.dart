import 'user_position_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/api/official_team_api.dart';
import 'package:chat_messenger/helpers/ranking_helper.dart';

class AgencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Agency model
  static const String _agenciesCollection = 'agencies';
  static const String _hostsCollection = 'hosts';
  static const String _hostInvitationsCollection = 'host_invitations';
  static const String _agencyCommissionsCollection = 'agency_commissions';

  // Commission rate (10%)
  static const double _commissionRate = 0.10;

  // Create agency
  Future<String> createAgency({
    required String agencyName,
    required String logoUrl,
    required String agencyIdNumber,
    required AgencyOwner owner,
  }) async {
    try {
      debugPrint('🏢 Creating agency: $agencyName');
      
      final agencyId = _firestore.collection(_agenciesCollection).doc().id;
      
      final agencyData = {
        'agencyId': agencyId,
        'agencyName': agencyName,
        'logoUrl': logoUrl,
        'agencyIdNumber': agencyIdNumber,
        'owner': owner.toMap(),
        'ownerUserId': owner.userId,
        'isActive': true,
        'totalCommissionEarned': 0.0,
        'totalHosts': 0,
        'hostIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_agenciesCollection).doc(agencyId).set(agencyData);
      
      // Auto-apply Agency position items (Frame, Badge, Nameplate)
      try {
        await UserPositionService.applyPositionToUser(
          userId: owner.userId,
          positionKey: 'agency',
          userName: owner.name,
        );
      } catch (ex) {
        debugPrint('⚠️ Error applying agency position items: $ex');
      }
      
      debugPrint('✅ Agency created successfully: $agencyId');
      return agencyId;
    } catch (e) {
      debugPrint('❌ Error creating agency: $e');
      rethrow;
    }
  }

  // Get agency by ID
  Future<Agency?> getAgency(String agencyId) async {
    try {
      debugPrint('🏢 Fetching agency: $agencyId');
      
      final doc = await _firestore.collection(_agenciesCollection).doc(agencyId).get();
      
      if (doc.exists) {
        return Agency.fromMap(doc.data()!);
      } else {
        debugPrint('❌ Agency not found: $agencyId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching agency: $e');
      rethrow;
    }
  }

  // Get agency by Owner User ID
  Future<Agency?> getAgencyByOwner(String userId) async {
    try {
      debugPrint('🏢 Fetching agency for owner: $userId');
      
      final querySnapshot = await _firestore
          .collection(_agenciesCollection)
          .where('ownerUserId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return Agency.fromMap(querySnapshot.docs.first.data());
      } else {
        debugPrint('❌ Agency not found for owner: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching agency by owner: $e');
      return null;
    }
  }

  // Get all agencies
  Future<List<Agency>> getAllAgencies() async {
    try {
      debugPrint('🏢 Fetching all agencies');
      
      final querySnapshot = await _firestore
          .collection(_agenciesCollection)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Agency.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching agencies: $e');
      rethrow;
    }
  }

  // Update agency
  Future<void> updateAgency(String agencyId, Map<String, dynamic> updates) async {
    try {
      debugPrint('🏢 Updating agency: $agencyId');
      
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(_agenciesCollection).doc(agencyId).update(updates);
      
      debugPrint('✅ Agency updated successfully');
    } catch (e) {
      debugPrint('❌ Error updating agency: $e');
      rethrow;
    }
  }

  // Delete agency
  Future<void> deleteAgency(String agencyId) async {
    try {
      debugPrint('🏢 Deleting agency: $agencyId');
      
      await _firestore.collection(_agenciesCollection).doc(agencyId).delete();
      
      debugPrint('✅ Agency deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting agency: $e');
      rethrow;
    }
  }

  // Add host to agency
  Future<void> addHostToAgency({
    required String agencyId,
    required String hostUserId,
    required String hostName,
    required String hostEmail,
    required String hostPhone,
  }) async {
    try {
      debugPrint('👤 Adding host to agency: $agencyId');

      // Check if host record already exists for this user in this agency to prevent duplicates
      final duplicateQuery = await _firestore
          .collection(_hostsCollection)
          .where('agencyId', isEqualTo: agencyId)
          .where('userId', isEqualTo: hostUserId)
          .where('isActive', isEqualTo: true)
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        debugPrint('⚠️ Host record already exists for userId: $hostUserId in agencyId: $agencyId. Skipping creation.');
        return;
      }
      
      // Create host record
      final hostId = _firestore.collection(_hostsCollection).doc().id;
      final hostData = {
        'hostId': hostId,
        'userId': hostUserId,
        'agencyId': agencyId,
        'hostName': hostName,
        'profileImageUrl': '',
        'phone': hostPhone,
        'email': hostEmail,
        'joinedDate': FieldValue.serverTimestamp(),
        'lastActiveDate': FieldValue.serverTimestamp(),
        'isActive': true,
        'status': 'active',
        'performance': {
          'totalEarnings': 0.0,
          'totalDiamonds': 0,
          'totalLiveHours': 0,
          'totalGiftsReceived': 0,
          'averageRating': 0.0,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        'earnings': [],
        'notes': '',
      };
      
      await _firestore.collection(_hostsCollection).doc(hostId).set(hostData);
      
      // Update agency host count
      await _firestore.collection(_agenciesCollection).doc(agencyId).update({
        'totalHosts': FieldValue.increment(1),
        'hostIds': FieldValue.arrayUnion([hostId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Auto-apply Host position items (Frame, Badge, Nameplate)
      try {
        await UserPositionService.applyPositionToUser(
          userId: hostUserId,
          positionKey: 'host',
          userName: hostName,
        );
      } catch (ex) {
        debugPrint('⚠️ Error applying host position items: $ex');
      }
      
      debugPrint('✅ Host added to agency successfully');
    } catch (e) {
      debugPrint('❌ Error adding host to agency: $e');
      rethrow;
    }
  }

  // Remove host from agency
  Future<void> removeHostFromAgency(String agencyId, String hostId) async {
    try {
      debugPrint('👤 Removing host from agency: $agencyId');

      // Fetch host data before deactivating (for notification)
      String hostUserId = '';
      String agencyName = '';
      try {
        final hostDoc = await _firestore.collection(_hostsCollection).doc(hostId).get();
        if (hostDoc.exists) {
          hostUserId = hostDoc.data()?['userId'] ?? '';
        }
        final agencyDoc = await _firestore.collection(_agenciesCollection).doc(agencyId).get();
        if (agencyDoc.exists) {
          agencyName = agencyDoc.data()?['agencyName'] ?? '';
        }
      } catch (_) {}

      // Update host status
      await _firestore.collection(_hostsCollection).doc(hostId).update({
        'isActive': false,
        'status': 'terminated',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear user agency association to allow inviting them again
      if (hostUserId.isNotEmpty) {
        try {
          await UserPositionService.removePositionFromUser(
            userId: hostUserId,
            positionKey: 'host',
          );
        } catch (ex) {
          debugPrint('⚠️ Error removing host position items: $ex');
        }
        await _firestore.collection('Users').doc(hostUserId).update({
          'agencyId': null,
          'agencyName': null,
          'isHost': false,
          'userType': 'regular',
          'roles': FieldValue.arrayRemove(['host']),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Cancel previous pending invitations for this user
        final pendingInvites = await _firestore
            .collection(_hostInvitationsCollection)
            .where('hostUserId', isEqualTo: hostUserId)
            .where('status', isEqualTo: 'pending')
            .get();
        for (var doc in pendingInvites.docs) {
          await doc.reference.update({
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      
      // Update agency host count
      await _firestore.collection(_agenciesCollection).doc(agencyId).update({
        'totalHosts': FieldValue.increment(-1),
        'hostIds': FieldValue.arrayRemove([hostId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send termination notice via imChat official team
      if (hostUserId.isNotEmpty) {
        try {
          final userDoc = await _firestore.collection('Users').doc(hostUserId).get();
          final userData = userDoc.data();
          if (userData != null) {
            final user = await UserApi.getUser(hostUserId);
            if (user != null) {
              await OfficialTeamApi.sendHostTerminationNotice(
                user,
                agencyName.isNotEmpty ? agencyName : 'the agency',
              );
            }
          }
        } catch (ex) {
          debugPrint('⚠️ Failed to send official team termination notice: $ex');
        }
      }
      
      debugPrint('✅ Host removed from agency successfully');
    } catch (e) {
      debugPrint('❌ Error removing host from agency: $e');
      rethrow;
    }
  }

  // Send host invitation
  Future<void> sendHostInvitation({
    required String agencyId,
    required String agencyName,
    required String hostUserId,
    required String hostName,
    required String hostEmail,
    required String hostPhone,
    required String message,
  }) async {
    try {
      debugPrint('📧 Sending host invitation to: $hostEmail');

      final invitationId = _firestore.collection(_hostInvitationsCollection).doc().id;
      final invitationData = {
        'invitationId': invitationId,
        'agencyId': agencyId,
        'hostUserId': hostUserId,
        'hostName': hostName,
        'hostEmail': hostEmail,
        'hostPhone': hostPhone,
        'status': 'pending',
        'sentAt': FieldValue.serverTimestamp(),
        'message': message,
        'agencyName': agencyName,
      };

      await _firestore.collection(_hostInvitationsCollection).doc(invitationId).set(invitationData);

      // Send interactive invitation card via imChat official team
      try {
        final userDoc = await _firestore.collection('Users').doc(hostUserId).get();
        final deviceToken = userDoc.data()?['deviceToken'] ?? '';
        await OfficialTeamApi.sendHostInvitationMessage(
          receiverId: hostUserId,
          receiverDeviceToken: deviceToken,
          receiverName: hostName,
          invitationId: invitationId,
          agencyId: agencyId,
          agencyName: agencyName,
        );
      } catch (ex) {
        debugPrint('⚠️ Failed to send official team invitation message: $ex');
      }

      debugPrint('✅ Host invitation sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending host invitation: $e');
      rethrow;
    }
  }

  // Get agency hosts
  Future<List<Host>> getAgencyHosts(String agencyId) async {
    try {
      debugPrint('👤 Fetching agency hosts: $agencyId');
      
      final querySnapshot = await _firestore
          .collection(_hostsCollection)
          .where('agencyId', isEqualTo: agencyId)
          .orderBy('joinedDate', descending: true)
          .get();
      
      final List<Host> uniqueHosts = [];
      final Set<String> seenUserIds = {};
      
      for (var doc in querySnapshot.docs) {
        final host = Host.fromMap(doc.data());
        if (host.isActive && !seenUserIds.contains(host.userId)) {
          seenUserIds.add(host.userId);
          uniqueHosts.add(host);
        }
      }
      return uniqueHosts;
    } catch (e) {
      debugPrint('❌ Error fetching agency hosts: $e');
      rethrow;
    }
  }

  // Calculate commission
  Future<void> calculateCommission({
    required String hostId,
    required String agencyId,
    required double earnings,
    required String period,
    required String description,
  }) async {
    try {
      debugPrint('💰 Calculating commission for host: $hostId');
      
      final commissionAmount = earnings * _commissionRate;
      
      // Create commission record
      final commissionId = _firestore.collection(_agencyCommissionsCollection).doc().id;
      final commissionData = {
        'commissionId': commissionId,
        'hostId': hostId,
        'agencyId': agencyId,
        'earnings': earnings,
        'commissionAmount': commissionAmount,
        'commissionRate': _commissionRate,
        'period': period,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_agencyCommissionsCollection).doc(commissionId).set(commissionData);
      
      // Update agency total commission
      await _firestore.collection(_agenciesCollection).doc(agencyId).update({
        'totalCommissionEarned': FieldValue.increment(commissionAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Commission calculated: $commissionAmount');
    } catch (e) {
      debugPrint('❌ Error calculating commission: $e');
      rethrow;
    }
  }

  // Get agency analytics
  Future<Map<String, dynamic>> getAgencyAnalytics(String agencyId) async {
    try {
      debugPrint('📊 Fetching agency analytics: $agencyId');
      
      final agency = await getAgency(agencyId);
      if (agency == null) {
        throw Exception('Agency not found');
      }
      
      final hosts = await getAgencyHosts(agencyId);
      
      // Calculate analytics
      double totalEarnings = 0;
      int totalDiamonds = 0;
      double totalLiveHours = 0;
      int totalGifts = 0;
      double averageRating = 0;
      
      for (final host in hosts) {
        totalEarnings += host.performance.totalEarnings;
        totalDiamonds += host.performance.totalDiamonds;
        totalLiveHours += host.performance.totalLiveHours;
        totalGifts += host.performance.totalGiftsReceived;
        averageRating += host.performance.averageRating;
      }
      
      if (hosts.isNotEmpty) {
        averageRating /= hosts.length;
      }
      
      return {
        'agency': agency,
        'totalHosts': hosts.length,
        'totalEarnings': totalEarnings,
        'totalDiamonds': totalDiamonds,
        'totalLiveHours': totalLiveHours,
        'totalGifts': totalGifts,
        'averageRating': averageRating,
        'totalCommissionEarned': agency.totalCommissionEarned,
      };
    } catch (e) {
      debugPrint('❌ Error fetching agency analytics: $e');
      rethrow;
    }
  }

  // Get pending invitations for a user (resolves agency name if missing)
  Future<List<Map<String, dynamic>>> getUserPendingInvitations(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_hostInvitationsCollection)
          .where('hostUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        // Always use the Firestore document ID as the canonical invitationId
        data['invitationId'] = doc.id;
        // Resolve agency name if missing
        if ((data['agencyName'] ?? '').toString().isEmpty && data['agencyId'] != null) {
          final agency = await getAgency(data['agencyId']);
          if (agency != null) {
            data['agencyName'] = agency.agencyName;
          }
        }
        results.add(data);
      }
      return results;
    } catch (e) {
      debugPrint('❌ Error fetching pending invitations: $e');
      rethrow;
    }
  }

  // Accept an invitation
  Future<void> acceptInvitation(String invitationId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final invRef = _firestore.collection(_hostInvitationsCollection).doc(invitationId);
        final invSnap = await transaction.get(invRef);
        if (!invSnap.exists) throw Exception('Invitation not found');

        final invData = invSnap.data()!;
        final status = invData['status'] ?? 'pending';
        if (status != 'pending') {
          throw Exception('This invitation has already been accepted or responded to.');
        }

        final agencyId = invData['agencyId'] as String;

        // Check if user is already an active host of another agency
        final userRef = _firestore.collection('Users').doc(userId);
        final userSnap = await transaction.get(userRef);
        bool isOwner = false;
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final existingAgencyId = userData['agencyId'] as String?;
          final isAgency = userData['isAgency'] as bool? ?? false;
          isOwner = isAgency;
          if (existingAgencyId != null && existingAgencyId.isNotEmpty && existingAgencyId != agencyId) {
            throw Exception('You are already an active Host of another agency. Please leave that agency before joining a new one.');
          }
        }

        final agencyRef = _firestore.collection(_agenciesCollection).doc(agencyId);
        final agencySnap = await transaction.get(agencyRef);
        if (!agencySnap.exists) throw Exception('Agency not found');

        final agencyName = agencySnap.data()!['agencyName'] as String? ?? '';
        if (agencySnap.data()?['ownerUserId'] == userId) {
          isOwner = true;
        }

        // Update invitation status
        transaction.update(invRef, {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()});

        // Update user doc - preserve agency ownership while adding host role
        transaction.update(userRef, {
          'agencyId': agencyId,
          'agencyName': agencyName,
          'userType': isOwner ? 'agency' : 'host',
          'isHost': true,
          if (isOwner) 'isAgency': true,
          'roles': FieldValue.arrayUnion(['host', if (isOwner) 'agency']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Add host to agency (outside transaction since addHostToAgency uses FieldValue.increment)
      final invDoc = await _firestore.collection(_hostInvitationsCollection).doc(invitationId).get();
      final invData = invDoc.data()!;
      await addHostToAgency(
        agencyId: invData['agencyId'],
        hostUserId: userId,
        hostName: invData['hostName'] ?? '',
        hostEmail: invData['hostEmail'] ?? '',
        hostPhone: invData['hostPhone'] ?? '',
      );

      // Trigger official team Host Congratulation notification
      try {
        final user = await UserApi.getUser(userId);
        if (user != null) {
          await OfficialTeamApi.sendHostCongratulation(user);
        }
      } catch (ex) {
        debugPrint('Error sending official host congratulation notification: $ex');
      }

      debugPrint('✅ Invitation accepted successfully');
    } catch (e) {
      debugPrint('❌ Error accepting invitation: $e');
      rethrow;
    }
  }

  // Reject an invitation
  Future<void> rejectInvitation(String invitationId) async {
    try {
      await _firestore.collection(_hostInvitationsCollection).doc(invitationId).update({
        'status': 'rejected',
      });
      debugPrint('✅ Invitation rejected');
    } catch (e) {
      debugPrint('❌ Error rejecting invitation: $e');
      rethrow;
    }
  }

  // Get active host record for a user
  Future<Host?> getUserHostRecord(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_hostsCollection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Host.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user host record: $e');
      rethrow;
    }
  }

  // Get agency by owner user ID
  Future<Agency?> getAgencyByOwnerId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_agenciesCollection)
          .where('ownerUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Agency.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching agency by owner: $e');
      rethrow;
    }
  }

  // Search agency by agencyIdNumber, agencyId, or owner's searchId
  Future<Agency?> findAgencyByIdOrNumber(String query) async {
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return null;

      // 1. Search by agencyIdNumber
      final numSnapshot = await _firestore
          .collection(_agenciesCollection)
          .where('agencyIdNumber', isEqualTo: cleanQuery)
          .limit(1)
          .get();

      if (numSnapshot.docs.isNotEmpty) {
        return Agency.fromMap(numSnapshot.docs.first.data());
      }

      // 2. Search by agencyId (document ID)
      final docSnapshot = await _firestore
          .collection(_agenciesCollection)
          .doc(cleanQuery)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        return Agency.fromMap(docSnapshot.data()!);
      }

      // 3. Search by owner's searchId in Users collection
      final userSnapshot = await _firestore
          .collection('Users')
          .where('searchId', isEqualTo: cleanQuery)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data();
        final String? ownerAgencyId = userData['agencyId'];
        if (ownerAgencyId != null && ownerAgencyId.isNotEmpty) {
          final agency = await getAgency(ownerAgencyId);
          if (agency != null) return agency;
        }
        // Also check if user is agency owner by ownerUserId
        final agencyByOwner = await getAgencyByOwner(userSnapshot.docs.first.id);
        if (agencyByOwner != null) return agencyByOwner;
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error finding agency by ID/number: $e');
      return null;
    }
  }

  // Get active pending transfer request for a user
  Future<Map<String, dynamic>?> getPendingTransferRequest(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('agency_transfer_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'id': snapshot.docs.first.id,
          ...snapshot.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching pending transfer request: $e');
      return null;
    }
  }

  // Submit agency transfer request
  Future<String> submitTransferRequest({
    required String userId,
    required String userName,
    required String userSearchId,
    required String userPhotoUrl,
    required String currentAgencyId,
    required String currentAgencyName,
    required String currentAgencyIdNumber,
    required Agency targetAgency,
    String? reason,
  }) async {
    try {
      // Check for existing pending request
      final existing = await getPendingTransferRequest(userId);
      if (existing != null) {
        throw Exception('You already have a pending agency transfer request.');
      }

      if (currentAgencyId == targetAgency.agencyId) {
        throw Exception('You are already registered under this agency.');
      }

      final docRef = _firestore.collection('agency_transfer_requests').doc();
      final requestData = {
        'requestId': docRef.id,
        'userId': userId,
        'userName': userName,
        'userSearchId': userSearchId,
        'userPhotoUrl': userPhotoUrl,
        'currentAgencyId': currentAgencyId,
        'currentAgencyName': currentAgencyName,
        'currentAgencyIdNumber': currentAgencyIdNumber,
        'targetAgencyId': targetAgency.agencyId,
        'targetAgencyName': targetAgency.agencyName,
        'targetAgencyIdNumber': targetAgency.agencyIdNumber,
        'targetOwnerUserId': targetAgency.owner.userId,
        'targetOwnerName': targetAgency.owner.name,
        'targetLogoUrl': targetAgency.logoUrl,
        'reason': reason ?? '',
        'status': 'pending', // 'pending', 'approved', 'rejected', 'cancelled'
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(requestData);
      debugPrint('✅ Agency transfer request submitted: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error submitting agency transfer request: $e');
      rethrow;
    }
  }

  // Cancel an agency transfer request by user
  Future<void> cancelTransferRequest(String requestId) async {
    try {
      await _firestore.collection('agency_transfer_requests').doc(requestId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Agency transfer request cancelled: $requestId');
    } catch (e) {
      debugPrint('❌ Error cancelling transfer request: $e');
      rethrow;
    }
  }

  // Admin Approve Agency Transfer Request
  Future<void> approveTransferRequest({
    required String requestId,
    required String adminId,
  }) async {
    try {
      final doc = await _firestore.collection('agency_transfer_requests').doc(requestId).get();
      if (!doc.exists) throw Exception('Request not found');
      final data = doc.data()!;

      if (data['status'] != 'pending') {
        throw Exception('This request is already ${data['status']}');
      }

      final String userId = data['userId'];
      final String targetAgencyId = data['targetAgencyId'];
      final String targetAgencyName = data['targetAgencyName'] ?? 'New Agency';
      final String currentAgencyId = data['currentAgencyId'] ?? '';

      // 1. Update User doc
      await _firestore.collection('Users').doc(userId).update({
        'agencyId': targetAgencyId,
        'agencyName': targetAgencyName,
        'isHost': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update or Create Host doc
      final hostSnapshot = await _firestore
          .collection(_hostsCollection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (hostSnapshot.docs.isNotEmpty) {
        await hostSnapshot.docs.first.reference.update({
          'agencyId': targetAgencyId,
          'isActive': true,
          'status': 'active',
          'notes': 'Transferred to $targetAgencyName',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final newHostRef = _firestore.collection(_hostsCollection).doc();
        await newHostRef.set({
          'hostId': newHostRef.id,
          'userId': userId,
          'agencyId': targetAgencyId,
          'hostName': data['userName'] ?? '',
          'profileImageUrl': data['userPhotoUrl'] ?? '',
          'phone': '',
          'email': '',
          'joinedDate': FieldValue.serverTimestamp(),
          'lastActiveDate': FieldValue.serverTimestamp(),
          'isActive': true,
          'status': 'active',
          'performance': {
            'totalEarnings': 0.0,
            'totalDiamonds': 0,
            'totalLiveHours': 0.0,
            'totalGiftsReceived': 0,
            'averageRating': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          'earnings': [],
          'notes': 'Transferred to $targetAgencyName',
        });
      }

      // 3. Remove host from old agency if valid
      if (currentAgencyId.isNotEmpty) {
        try {
          await _firestore.collection(_agenciesCollection).doc(currentAgencyId).update({
            'totalHosts': FieldValue.increment(-1),
            'hostIds': FieldValue.arrayRemove([userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }

      // 4. Add host to target agency
      try {
        await _firestore.collection(_agenciesCollection).doc(targetAgencyId).update({
          'totalHosts': FieldValue.increment(1),
          'hostIds': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      // 5. Update transfer request status
      await _firestore.collection('agency_transfer_requests').doc(requestId).update({
        'status': 'approved',
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 6. Send official notification to the user
      try {
        final targetUser = await UserApi.getUser(userId);
        if (targetUser != null) {
          await OfficialTeamApi.sendOfficialMessage(
            receiverId: userId,
            receiverDeviceToken: targetUser.deviceToken,
            messageText: '🎉 Congratulations! Your request to change agency to "$targetAgencyName" has been approved by the Admin.',
          );
        }
      } catch (ex) {
        debugPrint('⚠️ Error sending official notification: $ex');
      }

      debugPrint('✅ Agency transfer approved for user $userId to agency $targetAgencyId');
    } catch (e) {
      debugPrint('❌ Error approving agency transfer: $e');
      rethrow;
    }
  }

  // Admin Reject Agency Transfer Request
  Future<void> rejectTransferRequest({
    required String requestId,
    required String adminId,
    String? rejectionReason,
  }) async {
    try {
      final doc = await _firestore.collection('agency_transfer_requests').doc(requestId).get();
      if (!doc.exists) throw Exception('Request not found');
      final data = doc.data()!;

      if (data['status'] != 'pending') {
        throw Exception('This request is already ${data['status']}');
      }

      final String userId = data['userId'];
      final String targetAgencyName = data['targetAgencyName'] ?? 'the requested agency';

      // Update transfer request doc
      await _firestore.collection('agency_transfer_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': rejectionReason ?? 'Request was rejected by admin.',
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send official notification to user
      try {
        final targetUser = await UserApi.getUser(userId);
        if (targetUser != null) {
          final reasonText = (rejectionReason != null && rejectionReason.isNotEmpty)
              ? '\nReason: $rejectionReason'
              : '';
          await OfficialTeamApi.sendOfficialMessage(
            receiverId: userId,
            receiverDeviceToken: targetUser.deviceToken,
            messageText: '❌ Your request to change agency to "$targetAgencyName" was rejected.$reasonText',
          );
        }
      } catch (ex) {
        debugPrint('⚠️ Error sending official rejection notification: $ex');
      }

      debugPrint('✅ Agency transfer rejected: $requestId');
    } catch (e) {
      debugPrint('❌ Error rejecting agency transfer: $e');
      rethrow;
    }
  }

  // Search user by searchId
  Future<Map<String, dynamic>?> searchUserBySearchId(String searchId) async {
    try {
      final querySnapshot = await _firestore
          .collection('Users')
          .where('searchId', isEqualTo: searchId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error searching user by searchId: $e');
      rethrow;
    }
  }

  // Get pending invitations sent by an agency
  Future<List<Map<String, dynamic>>> getAgencyPendingInvitations(String agencyId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_hostInvitationsCollection)
          .where('agencyId', isEqualTo: agencyId)
          .where('status', isEqualTo: 'pending')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['invitationId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching agency pending invitations: $e');
      rethrow;
    }
  }

  // Leave agency (host leaves)
  Future<void> leaveAgency(String userId) async {
    try {
      // Find and deactivate host record
      try {
        await UserPositionService.removePositionFromUser(
          userId: userId,
          positionKey: 'host',
        );
      } catch (ex) {
        debugPrint('⚠️ Error removing host position items on leave: $ex');
      }
      final hostRecord = await getUserHostRecord(userId);
      if (hostRecord != null) {
        await removeHostFromAgency(hostRecord.agencyId, hostRecord.hostId);
      } else {
        // Clear user agency fields
        await _firestore.collection('Users').doc(userId).update({
          'agencyId': null,
          'agencyName': null,
          'isHost': false,
          'userType': 'regular',
          'roles': FieldValue.arrayRemove(['host']),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ User left agency successfully');
    } catch (e) {
      debugPrint('❌ Error leaving agency: $e');
      rethrow;
    }
  }

  /// Stream claimed tiers for the given agency and week cycle
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTierClaims({
    required String agencyId,
    required String cycleSuffix,
  }) {
    return _firestore
        .collection(_agenciesCollection)
        .doc(agencyId)
        .collection('tier_claims')
        .doc(cycleSuffix)
        .snapshots();
  }

  /// Claim a single tier reward for an agency owner (incremental milestone payout)
  Future<int> claimTierReward({
    required String agencyId,
    required String ownerUserId,
    required String cycleSuffix,
    required int tierIndex,
    required int milestoneReward,
    required String tierLabel,
  }) async {
    try {
      final claimDocRef = _firestore
          .collection(_agenciesCollection)
          .doc(agencyId)
          .collection('tier_claims')
          .doc(cycleSuffix);

      final claimSnapshot = await claimDocRef.get();
      final claimData = claimSnapshot.data();
      final claimedTiers = List<int>.from(claimData?['claimedTiers'] ?? []);
      final int totalClaimedSoFar = (claimData?['totalClaimed'] as num?)?.toInt() ?? 0;

      if (claimedTiers.contains(tierIndex)) {
        debugPrint('⚠️ Tier $tierIndex is already claimed for cycle $cycleSuffix');
        return 0;
      }

      // Calculate net incremental payout = milestoneReward - totalClaimedSoFar
      final int netPayout = milestoneReward - totalClaimedSoFar;
      if (netPayout <= 0) {
        // Already received equivalent or higher amount from previous claims
        await claimDocRef.set({
          'claimedTiers': FieldValue.arrayUnion([tierIndex]),
        }, SetOptions(merge: true));
        return 0;
      }

      // Mark this tier and all preceding tiers as claimed
      final List<int> tiersToMark = [];
      for (int i = 0; i <= tierIndex; i++) {
        if (!claimedTiers.contains(i)) {
          tiersToMark.add(i);
        }
      }

      final batch = _firestore.batch();

      // 1. Credit net beans to agency owner wallet
      final userRef = _firestore.collection('Users').doc(ownerUserId);
      batch.update(userRef, {
        'beans': FieldValue.increment(netPayout),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Record wallet transaction
      final txRef = _firestore.collection('wallet_transactions').doc();
      batch.set(txRef, {
        'id': txRef.id,
        'userId': ownerUserId,
        'type': 'agency_tier_reward',
        'beans': netPayout,
        'diamonds': 0,
        'description': 'Agency Weekly Reward: $tierLabel (+${netPayout} beans net, milestone $milestoneReward)',
        'agencyId': agencyId,
        'cycle': cycleSuffix,
        'tierIndex': tierIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Update tier claims document
      batch.set(claimDocRef, {
        'agencyId': agencyId,
        'ownerUserId': ownerUserId,
        'cycle': cycleSuffix,
        'claimedTiers': FieldValue.arrayUnion(tiersToMark),
        'claimedAmounts': {
          '$tierIndex': netPayout,
        },
        'totalClaimed': FieldValue.increment(netPayout),
        'lastClaimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update total commission on agency
      final agencyRef = _firestore.collection(_agenciesCollection).doc(agencyId);
      batch.update(agencyRef, {
        'totalCommissionEarned': FieldValue.increment(netPayout.toDouble()),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Successfully claimed Tier $tierIndex reward: $netPayout beans (milestone $milestoneReward - already claimed $totalClaimedSoFar)');
      return netPayout;
    } catch (e) {
      debugPrint('❌ Error claiming tier reward: $e');
      rethrow;
    }
  }

  /// Claim all eligible unclaimed tiers at once (incremental payout)
  Future<int> claimAllEligibleTiers({
    required String agencyId,
    required String ownerUserId,
    required String cycleSuffix,
    required List<Map<String, dynamic>> eligibleTiers,
  }) async {
    try {
      if (eligibleTiers.isEmpty) return 0;

      final claimDocRef = _firestore
          .collection(_agenciesCollection)
          .doc(agencyId)
          .collection('tier_claims')
          .doc(cycleSuffix);

      final claimSnapshot = await claimDocRef.get();
      final claimData = claimSnapshot.data();
      final claimedTiers = List<int>.from(claimData?['claimedTiers'] ?? []);
      final int totalClaimedSoFar = (claimData?['totalClaimed'] as num?)?.toInt() ?? 0;

      // Find highest milestone reward among eligible tiers
      int highestMilestoneReward = 0;
      final List<int> newClaimedIndices = [];

      for (var t in eligibleTiers) {
        final int r = (t['reward'] as num).toInt();
        final int idx = t['index'] as int;
        if (r > highestMilestoneReward) {
          highestMilestoneReward = r;
        }
        if (!claimedTiers.contains(idx)) {
          newClaimedIndices.add(idx);
        }
      }

      final int netPayout = highestMilestoneReward - totalClaimedSoFar;
      if (netPayout <= 0 || newClaimedIndices.isEmpty) {
        if (newClaimedIndices.isNotEmpty) {
          await claimDocRef.set({
            'claimedTiers': FieldValue.arrayUnion(newClaimedIndices),
          }, SetOptions(merge: true));
        }
        return 0;
      }

      final batch = _firestore.batch();

      // 1. Credit beans to owner
      final userRef = _firestore.collection('Users').doc(ownerUserId);
      batch.update(userRef, {
        'beans': FieldValue.increment(netPayout),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Transaction log
      final txRef = _firestore.collection('wallet_transactions').doc();
      batch.set(txRef, {
        'id': txRef.id,
        'userId': ownerUserId,
        'type': 'agency_tier_reward',
        'beans': netPayout,
        'diamonds': 0,
        'description': 'Agency Weekly Reward: Claimed ${newClaimedIndices.length} Tiers (+${netPayout} beans net, milestone $highestMilestoneReward)',
        'agencyId': agencyId,
        'cycle': cycleSuffix,
        'tierIndices': newClaimedIndices,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Claims doc
      batch.set(claimDocRef, {
        'agencyId': agencyId,
        'ownerUserId': ownerUserId,
        'cycle': cycleSuffix,
        'claimedTiers': FieldValue.arrayUnion(newClaimedIndices),
        'totalClaimed': FieldValue.increment(netPayout),
        'lastClaimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update agency
      final agencyRef = _firestore.collection(_agenciesCollection).doc(agencyId);
      batch.update(agencyRef, {
        'totalCommissionEarned': FieldValue.increment(netPayout.toDouble()),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ Successfully claimed all net: $netPayout beans');
      return netPayout;
    } catch (e) {
      debugPrint('❌ Error claiming all tiers: $e');
      rethrow;
    }
  }

  /// Auto-claim previous week's unclaimed rewards (incremental milestone payout)
  Future<int> autoClaimPreviousWeekRewards({
    required String agencyId,
    required String ownerUserId,
    required int previousWeekPoints,
    required List<Map<String, dynamic>> tiers,
  }) async {
    try {
      if (previousWeekPoints <= 0 || tiers.isEmpty) return 0;

      final prevCycleSuffix = RankingHelper.previousMondayWeeklySuffix;
      final claimDocRef = _firestore
          .collection(_agenciesCollection)
          .doc(agencyId)
          .collection('tier_claims')
          .doc(prevCycleSuffix);

      final claimSnapshot = await claimDocRef.get();
      final claimData = claimSnapshot.data();
      final claimedTiers = List<int>.from(claimData?['claimedTiers'] ?? []);
      final int prevTotalClaimed = (claimData?['totalClaimed'] as num?)?.toInt() ?? 0;

      final eligibleTiers = <Map<String, dynamic>>[];
      int highestEligibleReward = 0;

      for (int i = 0; i < tiers.length; i++) {
        final target = (tiers[i]['target'] as num).toInt();
        final reward = (tiers[i]['reward'] as num).toInt();
        if (previousWeekPoints >= target) {
          if (reward > highestEligibleReward) {
            highestEligibleReward = reward;
          }
          if (!claimedTiers.contains(i)) {
            eligibleTiers.add({
              'index': i,
              'reward': reward,
              'label': tiers[i]['label'] ?? 'Tier ${i + 1}',
            });
          }
        }
      }

      if (eligibleTiers.isEmpty || highestEligibleReward <= prevTotalClaimed) return 0;

      return await claimAllEligibleTiers(
        agencyId: agencyId,
        ownerUserId: ownerUserId,
        cycleSuffix: prevCycleSuffix,
        eligibleTiers: eligibleTiers,
      );
    } catch (e) {
      debugPrint('⚠️ Error in auto-claiming previous week: $e');
      return 0;
    }
  }
}

// Agency model
class Agency {
  final String agencyId;
  final String agencyName;
  final String logoUrl;
  final String agencyIdNumber;
  final AgencyOwner owner;
  final bool isActive;
  final double totalCommissionEarned;
  final int totalHosts;
  final List<String> hostIds;
  final double? commissionRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Agency({
    required this.agencyId,
    required this.agencyName,
    required this.logoUrl,
    required this.agencyIdNumber,
    required this.owner,
    required this.isActive,
    required this.totalCommissionEarned,
    required this.totalHosts,
    required this.hostIds,
    this.commissionRate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Agency.fromMap(Map<String, dynamic> data) {
    return Agency(
      agencyId: data['agencyId'] ?? '',
      agencyName: data['agencyName'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      agencyIdNumber: data['agencyIdNumber'] ?? '',
      owner: AgencyOwner.fromMap(data['owner'] ?? {}),
      isActive: data['isActive'] ?? true,
      totalCommissionEarned: (data['totalCommissionEarned'] ?? 0).toDouble(),
      totalHosts: data['totalHosts'] ?? 0,
      hostIds: List<String>.from(data['hostIds'] ?? []),
      commissionRate: (data['commissionRate'] as num?)?.toDouble(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'agencyId': agencyId,
      'agencyName': agencyName,
      'logoUrl': logoUrl,
      'agencyIdNumber': agencyIdNumber,
      'owner': owner.toMap(),
      'isActive': isActive,
      'totalCommissionEarned': totalCommissionEarned,
      'totalHosts': totalHosts,
      'hostIds': hostIds,
      if (commissionRate != null) 'commissionRate': commissionRate,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Agency Owner model
class AgencyOwner {
  final String userId;
  final String name;
  final String phone;
  final String email;
  final String profileImageUrl;
  final DateTime dateOfBirth;
  final String address;

  AgencyOwner({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.profileImageUrl,
    required this.dateOfBirth,
    required this.address,
  });

  factory AgencyOwner.fromMap(Map<String, dynamic> data) {
    return AgencyOwner(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      dateOfBirth: data['dateOfBirth']?.toDate() ?? DateTime.now(),
      address: data['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'address': address,
    };
  }
}

// Host model
class Host {
  final String hostId;
  final String userId;
  final String agencyId;
  final String hostName;
  final String profileImageUrl;
  final String phone;
  final String email;
  final DateTime joinedDate;
  final DateTime lastActiveDate;
  final bool isActive;
  final String status;
  final HostPerformance performance;
  final List<HostEarning> earnings;
  final String notes;

  Host({
    required this.hostId,
    required this.userId,
    required this.agencyId,
    required this.hostName,
    required this.profileImageUrl,
    required this.phone,
    required this.email,
    required this.joinedDate,
    required this.lastActiveDate,
    required this.isActive,
    required this.status,
    required this.performance,
    required this.earnings,
    required this.notes,
  });

  factory Host.fromMap(Map<String, dynamic> data) {
    return Host(
      hostId: data['hostId'] ?? '',
      userId: data['userId'] ?? '',
      agencyId: data['agencyId'] ?? '',
      hostName: data['hostName'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      joinedDate: data['joinedDate']?.toDate() ?? DateTime.now(),
      lastActiveDate: data['lastActiveDate']?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      status: data['status'] ?? 'active',
      performance: HostPerformance.fromMap(data['performance'] ?? {}),
      earnings: data['earnings'] != null 
          ? (data['earnings'] as List).map((e) => HostEarning.fromMap(e)).toList()
          : [],
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'userId': userId,
      'agencyId': agencyId,
      'hostName': hostName,
      'profileImageUrl': profileImageUrl,
      'phone': phone,
      'email': email,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'lastActiveDate': Timestamp.fromDate(lastActiveDate),
      'isActive': isActive,
      'status': status,
      'performance': performance.toMap(),
      'earnings': earnings.map((e) => e.toMap()).toList(),
      'notes': notes,
    };
  }
}

// Host Performance model
class HostPerformance {
  final double totalEarnings;
  final int totalDiamonds;
  final double totalLiveHours;
  final double weeklyLiveHours;
  final int totalGiftsReceived;
  final double averageRating;
  final DateTime lastUpdated;

  HostPerformance({
    required this.totalEarnings,
    required this.totalDiamonds,
    required this.totalLiveHours,
    this.weeklyLiveHours = 0.0,
    required this.totalGiftsReceived,
    required this.averageRating,
    required this.lastUpdated,
  });

  factory HostPerformance.fromMap(Map<String, dynamic> data) {
    final weeklyKey = 'weeklyLiveHours_${RankingHelper.mondayWeeklySuffix}';
    return HostPerformance(
      totalEarnings: ((data['totalEarnings'] as num?) ?? 0).toDouble(),
      totalDiamonds: (data['totalDiamonds'] as num?)?.toInt() ?? 0,
      totalLiveHours: ((data['totalLiveHours'] as num?) ?? 0).toDouble(),
      weeklyLiveHours: ((data[weeklyKey] as num?) ?? 0).toDouble(),
      totalGiftsReceived: (data['totalGiftsReceived'] as num?)?.toInt() ?? 0,
      averageRating: ((data['averageRating'] as num?) ?? 0).toDouble(),
      lastUpdated: data['lastUpdated']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalEarnings': totalEarnings,
      'totalDiamonds': totalDiamonds,
      'totalLiveHours': totalLiveHours,
      'totalGiftsReceived': totalGiftsReceived,
      'averageRating': averageRating,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

// Host Earning model
class HostEarning {
  final String id;
  final String hostId;
  final String agencyId;
  final double diamondsEarned;
  final double commissionAmount;
  final DateTime earningDate;
  final String period;
  final String description;

  HostEarning({
    required this.id,
    required this.hostId,
    required this.agencyId,
    required this.diamondsEarned,
    required this.commissionAmount,
    required this.earningDate,
    required this.period,
    required this.description,
  });

  factory HostEarning.fromMap(Map<String, dynamic> data) {
    return HostEarning(
      id: data['id'] ?? '',
      hostId: data['hostId'] ?? '',
      agencyId: data['agencyId'] ?? '',
      diamondsEarned: (data['diamondsEarned'] ?? 0).toDouble(),
      commissionAmount: (data['commissionAmount'] ?? 0).toDouble(),
      earningDate: data['earningDate']?.toDate() ?? DateTime.now(),
      period: data['period'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hostId': hostId,
      'agencyId': agencyId,
      'diamondsEarned': diamondsEarned,
      'commissionAmount': commissionAmount,
      'earningDate': Timestamp.fromDate(earningDate),
      'period': period,
      'description': description,
    };
  }
}