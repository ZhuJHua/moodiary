import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/values/webdav.dart';
import 'package:refreshed/refreshed.dart';

class WebDavDashboardState {
  Rx<WebDavConnectivityStatus> connectivityStatus =
      WebDavConnectivityStatus.connecting.obs;

  RxString webDavDiaryCount = '...'.obs;

  Map<String, String> webdavSyncMap = <String, String>{};

  // 所有的日记
  List<Diary> diaryList = <Diary>[];

  // 待上传的日记，有两种情况，一种是本地有，服务器没有，一种是本地有，服务器有，但是本地的更新时间比服务器的新
  List<Diary> toUploadDiaries = <Diary>[];

  RxString toUploadDiariesCount = '...'.obs;

  // 待下载的日记id，只有服务器有，本地没有的情况，或者本地有，但是服务器的更新时间比本地的新
  List<String> toDownloadIds = <String>[];

  RxString toDownloadIdsCount = '...'.obs;

  bool isFetching = true;

  RxBool isUploading = false.obs;
  RxBool isDownloading = false.obs;

  WebDavDashboardState() {
    ///Initialize variables
  }
}
