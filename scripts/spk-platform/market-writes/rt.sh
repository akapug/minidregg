# WBO is declared through the native conversation engine; this legacy HTTP row
# has no attached native receiver yet and must not invoke a second interpreter.
write_WBO() { echo '0 native-conversation-receiver-not-attached: wbo rectangle.write requires native qualification'; }

# The typed declarations own Wekan/Gogs methods, authentication and read-back.
# These rows exercise the same source that emits their Hermes schemas.
write_Wekan() { typed_app_row wekan; }
write_Gogs() { typed_app_row gogs; }
