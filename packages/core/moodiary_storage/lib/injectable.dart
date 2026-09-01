import 'package:injectable/injectable.dart';

/// micro-package 初始化锚点：生成 <包名>.module.dart，由 app 的
/// @InjectableInit(externalPackageModulesBefore:) 挂载。函数体刻意为空。
@InjectableInit.microPackage()
void initMicroPackage() {}
