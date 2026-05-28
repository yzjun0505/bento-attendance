# Flutter 基础混淆保留规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.external.application.** { *; }

# 腾讯云 IM & TRTC / TUIKit
-keep class com.tencent.** { *; }
-dontwarn com.tencent.**

# 忽略 Google Play Core (延迟组件/分包加载) 相关警告（解决 R8 报错）
-dontwarn com.google.android.play.core.**

# 高德地图与定位 (AMAP) SDK
-keep class com.amap.api.maps.**{*;}
-keep class com.autonavi.amap.mapcore.*{*;}
-keep class com.amap.api.trace.**{*;}
-keep class com.amap.api.location.**{*;}
-keep class com.amap.api.fence.**{*;}
-keep class com.autonavi.aps.amapapi.model.**{*;}
-keep class com.amap.api.services.**{*;}
-keep class com.amap.api.maps2d.**{*;}
-keep class com.amap.api.mapcore2d.**{*;}
-keep class com.amap.api.navi.**{*;}
-keep class com.autonavi.**{*;}
-dontwarn com.amap.api.**
-dontwarn com.autonavi.**
