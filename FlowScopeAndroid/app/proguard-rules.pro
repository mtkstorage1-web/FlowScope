# Keep kotlinx.serialization generated serializers for the classes we persist
# to DataStore / the widget bridge.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class mtk.flowscope.** {
    *** Companion;
}
-keepclasseswithmembers class mtk.flowscope.** {
    kotlinx.serialization.KSerializer serializer(...);
}
