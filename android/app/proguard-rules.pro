# Add ProGuard / R8 rules here if you need to keep classes/methods used by reflection.
# By default Flutter's engine and plugins include necessary rules, but add entries
# if R8 strips something you rely on.

# Example (keep model classes serialized via reflection):
#-keepclassmembers class com.example.** {
#    public <init>(...);
#}
