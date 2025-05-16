#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  audioplayers_windows
  bitsdojo_window_windows
  connectivity_plus
  dynamic_color
  fc_native_video_thumbnail
  file_selector_windows
  flutter_inappwebview_windows
  flutter_secure_storage_windows
  fvp
  gal
  geolocator_windows
  isar_flutter_libs
  local_auth_windows
  permission_handler_windows
  record_windows
  share_plus
  url_launcher_windows
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  moodiary_rust
  tflite_flutter
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
