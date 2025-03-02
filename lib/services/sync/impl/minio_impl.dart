// import 'dart:ui';
//
// import 'package:minio/minio.dart';
// import 'package:moodiary/common/models/isar/diary.dart';
// import 'package:moodiary/common/models/sync/sync.dart';
// import 'package:moodiary/services/sync/sync.dart';
//
// class MinioSyncServiceImpl implements SyncService {
//   final String endPoint;
//
//   final String accessKey;
//
//   final String secretKey;
//
//   final String bucketName;
//
//   late final Minio _client;
//
//   MinioSyncServiceImpl({
//     required this.endPoint,
//     required this.accessKey,
//     required this.secretKey,
//     required this.bucketName,
//   });
//
//   @override
//   Future<void> init() async {
//     _client = Minio(
//       endPoint: endPoint,
//       accessKey: accessKey,
//       secretKey: secretKey,
//     );
//   }
//
//   @override
//   Future<bool> checkConnectivity() {
//     // TODO: implement checkConnectivity
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult<Map<String, String>>> fetchServerSyncData() {
//     // TODO: implement fetchServerSyncData
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> updateServerSyncData(Map<String, String> syncData) {
//     // TODO: implement updateServerSyncData
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> deleteDiary({
//     required Diary diary,
//     VoidCallback? onStart,
//     VoidCallback? onComplete,
//     Function(int p1, int p2)? onProgress,
//   }) {
//     // TODO: implement deleteDiary
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> downloadDiary({
//     required String diaryId,
//     VoidCallback? onStart,
//     VoidCallback? onComplete,
//     Function(int p1, int p2)? onProgress,
//   }) {
//     // TODO: implement downloadDiary
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> updateDiary({
//     required Diary oldDiary,
//     required Diary newDiary,
//     VoidCallback? onStart,
//     VoidCallback? onComplete,
//     Function(int p1, int p2)? onProgress,
//   }) {
//     // TODO: implement updateDiary
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> uploadDiary({
//     required Diary diary,
//     VoidCallback? onStart,
//     VoidCallback? onComplete,
//     Function(int p1, int p2)? onProgress,
//   }) {
//     // TODO: implement uploadDiary
//     throw UnimplementedError();
//   }
//
//   @override
//   Future<SyncResult> syncDiary({
//     required List<Diary> diaries,
//     VoidCallback? onStart,
//     VoidCallback? onComplete,
//     Function(int p1, int p2)? onProgress,
//   }) {
//     // TODO: implement syncDiary
//     throw UnimplementedError();
//   }
// }
