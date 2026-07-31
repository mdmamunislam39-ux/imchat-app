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
        await _firestore.collection('Users').doc(hostUserId).update({
          'agencyId': null,
          'agencyName': null,
          'userType': 'regular',
          'updatedAt': FieldValue.serverTimestamp(),
        });
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

        // Check if user is already a host in any agency to prevent multiple memberships
        final userRef = _firestore.collection('Users').doc(userId);
        final userSnap = await transaction.get(userRef);
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final userType = userData['userType'] as String?;
          final existingAgencyId = userData['agencyId'] as String?;
          if (userType == 'host' || (existingAgencyId != null && existingAgencyId.isNotEmpty)) {
            throw Exception('You are already a Host of an agency. You cannot join multiple agencies.');
          }
        }

        final agencyRef = _firestore.collection(_agenciesCollection).doc(agencyId);
        final agencySnap = await transaction.get(agencyRef);
        if (!agencySnap.exists) throw Exception('Agency not found');

        final agencyName = agencySnap.data()!['agencyName'] as String? ?? '';

        // Update invitation status
        transaction.update(invRef, {'status': 'accepted'});

        // Update user doc
        transaction.update(userRef, {
          'agencyId': agencyId,
          'agencyName': agencyName,
          'userType': 'host',
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
      final hostRecord = await getUserHostRecord(userId);
      if (hostRecord != null) {
        await removeHostFromAgency(hostRecord.agencyId, hostRecord.hostId);
      }

      // Clear user agency fields
      await _firestore.collection('Users').doc(userId).update({
        'agencyId': null,
        'agencyName': null,
        'userType': 'regular',
      });

      debugPrint('✅ User left agency successfully');
    } catch (e) {
      debugPrint('❌ Error leaving agency: $e');
      rethrow;
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