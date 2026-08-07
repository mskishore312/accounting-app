# The google_mlkit_text_recognition plugin's initialize() method references a
# recognizer options class for every script ML Kit supports, and picks one at
# runtime. We only depend on the Latin recognizer, so the classes for the other
# scripts are genuinely absent from the APK and R8 fails on the dangling
# references. Silencing them is safe as long as bank_statement_service.dart keeps
# asking for TextRecognitionScript.latin — requesting another script at runtime
# would throw NoClassDefFoundError instead of failing the build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
