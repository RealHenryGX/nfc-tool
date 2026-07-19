/// NFC Tasks catalog — FOSS reimplementation of wakdev Task* screens.
/// Payloads use MIME `application/x-nfctoolbox-task` JSON.
class TaskKind {
  final String id;
  final String label;
  final String group;
  final String description;
  final bool needsPlatform;
  final bool rootRecommended;

  const TaskKind({
    required this.id,
    required this.label,
    required this.group,
    required this.description,
    this.needsPlatform = true,
    this.rootRecommended = false,
  });
}

class TaskCatalog {
  static const List<TaskKind> all = [
    // Connectivity
    TaskKind(id: 'wifi_state', label: 'Wi-Fi ON/OFF', group: 'connectivity', description: 'Toggle Wi-Fi radio'),
    TaskKind(id: 'wifi_network', label: 'Wi-Fi Network', group: 'connectivity', description: 'Connect / open Wi-Fi settings'),
    TaskKind(id: 'forgot_wifi', label: 'Forget Wi-Fi', group: 'connectivity', description: 'Open Wi-Fi forget flow'),
    TaskKind(id: 'hotspot_state', label: 'Hotspot ON/OFF', group: 'connectivity', description: 'Open hotspot settings'),
    TaskKind(id: 'bluetooth_state', label: 'Bluetooth ON/OFF', group: 'connectivity', description: 'Toggle Bluetooth'),
    TaskKind(id: 'bluetooth_discoverable', label: 'BT Discoverable', group: 'connectivity', description: 'Make device discoverable'),
    TaskKind(id: 'bluetooth_connect', label: 'BT Connect Device', group: 'connectivity', description: 'Connect paired device by MAC'),
    TaskKind(id: 'bluetooth_disconnect', label: 'BT Disconnect', group: 'connectivity', description: 'Disconnect Bluetooth device'),
    TaskKind(id: 'bluetooth_unpair', label: 'BT Unpair', group: 'connectivity', description: 'Unpair Bluetooth device'),
    TaskKind(id: 'nfc_state', label: 'NFC Settings', group: 'connectivity', description: 'Open NFC settings'),
    TaskKind(id: 'plane_state', label: 'Airplane Mode', group: 'connectivity', description: 'Open airplane-mode settings'),
    TaskKind(id: 'mobile_data', label: 'Mobile Data', group: 'connectivity', description: 'Open mobile-data settings'),
    TaskKind(id: 'gps_state', label: 'Location / GPS', group: 'connectivity', description: 'Open location settings'),

    // Sound / display
    TaskKind(id: 'sound_mode', label: 'Sound Mode', group: 'sound', description: 'Silent / vibrate / normal'),
    TaskKind(id: 'volume', label: 'Volume Level', group: 'sound', description: 'Set stream volume 0-100'),
    TaskKind(id: 'speaker_state', label: 'Speaker', group: 'sound', description: 'Speakerphone preference'),
    TaskKind(id: 'play_sound', label: 'Play Sound', group: 'sound', description: 'Play system / file sound'),
    TaskKind(id: 'vibrate', label: 'Vibrate', group: 'sound', description: 'Vibrate pattern'),
    TaskKind(id: 'brightness', label: 'Brightness', group: 'display', description: 'Set screen brightness'),
    TaskKind(id: 'adaptive_brightness', label: 'Adaptive Brightness', group: 'display', description: 'Toggle adaptive brightness'),
    TaskKind(id: 'brightness_mode', label: 'Brightness Mode', group: 'display', description: 'Manual / auto'),
    TaskKind(id: 'display_timeout', label: 'Display Timeout', group: 'display', description: 'Screen off timeout'),
    TaskKind(id: 'auto_rotate', label: 'Auto Rotate', group: 'display', description: 'Toggle auto-rotate'),
    TaskKind(id: 'flashlight', label: 'Flashlight', group: 'display', description: 'Torch on/off'),
    TaskKind(id: 'zen_mode', label: 'Zen / DND', group: 'display', description: 'Do Not Disturb'),
    TaskKind(id: 'expand_notifications', label: 'Expand Notifications', group: 'display', description: 'Open notification shade'),
    TaskKind(id: 'notification_alert', label: 'Notification Alert', group: 'display', description: 'Post local notification'),
    TaskKind(id: 'notification_light', label: 'Notification Light', group: 'display', description: 'LED settings intent'),

    // Apps / system
    TaskKind(id: 'launch_app', label: 'Launch App', group: 'apps', description: 'Start application by package'),
    TaskKind(id: 'app_details', label: 'App Details', group: 'apps', description: 'Open application info'),
    TaskKind(id: 'enable_app', label: 'Enable App', group: 'apps', description: 'Enable package', rootRecommended: true),
    TaskKind(id: 'disable_app', label: 'Disable App', group: 'apps', description: 'Disable package', rootRecommended: true),
    TaskKind(id: 'kill_app', label: 'Kill App', group: 'apps', description: 'Force-stop via settings'),
    TaskKind(id: 'kill_app_root', label: 'Kill App (Root)', group: 'apps', description: 'am force-stop', rootRecommended: true),
    TaskKind(id: 'uninstall_app', label: 'Uninstall App', group: 'apps', description: 'Uninstall package intent'),
    TaskKind(id: 'open_file', label: 'Open File', group: 'apps', description: 'VIEW file URI'),
    TaskKind(id: 'run_shortcut', label: 'Run Shortcut', group: 'apps', description: 'Launch shortcut'),
    TaskKind(id: 'send_intent', label: 'Send Intent', group: 'apps', description: 'Custom Android intent'),
    TaskKind(id: 'screenshot', label: 'Screenshot', group: 'apps', description: 'Trigger screenshot'),
    TaskKind(id: 'multi_window', label: 'Multi-Window', group: 'apps', description: 'Split-screen helpers'),
    TaskKind(id: 'power_saving', label: 'Power Saving', group: 'apps', description: 'Battery saver settings'),
    TaskKind(id: 'car_mode', label: 'Car Mode', group: 'apps', description: 'UiMode car'),
    TaskKind(id: 'driving_mode', label: 'Driving Mode', group: 'apps', description: 'Driving mode settings'),
    TaskKind(id: 'blocking_mode', label: 'Blocking Mode', group: 'apps', description: 'OEM blocking / focus'),
    TaskKind(id: 'sleep_timer', label: 'Sleep Timer', group: 'apps', description: 'Schedule screen off'),
    TaskKind(id: 'toolbox', label: 'System Toolbox', group: 'apps', description: 'Open system settings root'),
    TaskKind(id: 'tasker', label: 'Tasker Hook', group: 'apps', description: 'Broadcast to Tasker'),

    // Input / media
    TaskKind(id: 'clipboard', label: 'Clipboard', group: 'input', description: 'Copy text to clipboard'),
    TaskKind(id: 'keyboard', label: 'Keyboard Text', group: 'input', description: 'Inject / share text'),
    TaskKind(id: 'tts', label: 'Text-to-Speech', group: 'input', description: 'Speak text'),
    TaskKind(id: 'speak_time', label: 'Speak Time', group: 'input', description: 'Announce current time'),
    TaskKind(id: 'media_control', label: 'Media Control', group: 'input', description: 'Play/pause/next/prev'),
    TaskKind(id: 'start_rec_mic', label: 'Record Mic', group: 'input', description: 'Start audio capture intent'),
    TaskKind(id: 'morse', label: 'Morse Code', group: 'input', description: 'Vibrate Morse from text'),

    // Files
    TaskKind(id: 'file_copy', label: 'Copy File', group: 'files', description: 'Copy src → dst'),
    TaskKind(id: 'file_move', label: 'Move File', group: 'files', description: 'Move src → dst'),
    TaskKind(id: 'file_delete', label: 'Delete File', group: 'files', description: 'Delete path'),
    TaskKind(id: 'folder_copy', label: 'Copy Folder', group: 'files', description: 'Copy directory'),
    TaskKind(id: 'folder_move', label: 'Move Folder', group: 'files', description: 'Move directory'),
    TaskKind(id: 'folder_create', label: 'Create Folder', group: 'files', description: 'mkdir'),
    TaskKind(id: 'folder_delete', label: 'Delete Folder', group: 'files', description: 'rm -rf (careful)'),
    TaskKind(id: 'folder_zip', label: 'Zip Folder', group: 'files', description: 'Zip directory'),
    TaskKind(id: 'file_unzip', label: 'Unzip', group: 'files', description: 'Extract archive'),
    TaskKind(id: 'download_file', label: 'Download File', group: 'files', description: 'HTTP download to path'),
    TaskKind(id: 'write_file', label: 'Write File', group: 'files', description: 'Write text/bytes'),
    TaskKind(id: 'print_image', label: 'Print Image', group: 'files', description: 'Android print'),

    // Comms / net
    TaskKind(id: 'phone_call', label: 'Phone Call', group: 'comms', description: 'tel: dial'),
    TaskKind(id: 'send_sms', label: 'Send SMS', group: 'comms', description: 'sms: compose/send'),
    TaskKind(id: 'mail', label: 'Compose Mail', group: 'comms', description: 'mailto:'),
    TaskKind(id: 'http_get', label: 'HTTP GET', group: 'comms', description: 'Fetch URL'),
    TaskKind(id: 'http_post', label: 'HTTP POST', group: 'comms', description: 'POST body'),
    TaskKind(id: 'http_rest', label: 'HTTP REST', group: 'comms', description: 'Generic REST call'),
    TaskKind(id: 'ping', label: 'Ping', group: 'comms', description: 'ICMP/TCP reachability'),
    TaskKind(id: 'wol', label: 'Wake-on-LAN', group: 'comms', description: 'Magic packet'),
    TaskKind(id: 'send_udp', label: 'UDP Send', group: 'comms', description: 'UDP datagram'),
    TaskKind(id: 'twitter', label: 'Share / Tweet', group: 'comms', description: 'Share sheet'),

    // Maps tasks
    TaskKind(id: 'geocode', label: 'Open Geo', group: 'maps', description: 'geo: URI', needsPlatform: false),
    TaskKind(id: 'address', label: 'Open Address', group: 'maps', description: 'Maps address', needsPlatform: false),
    TaskKind(id: 'destination', label: 'Navigate', group: 'maps', description: 'Directions', needsPlatform: false),
    TaskKind(id: 'street_view', label: 'Street View', group: 'maps', description: 'Street View URL', needsPlatform: false),
    TaskKind(id: 'proximity_search', label: 'Proximity Search', group: 'maps', description: 'Local maps search', needsPlatform: false),
    TaskKind(id: 'url_uri', label: 'Open URL', group: 'maps', description: 'Open browser URI', needsPlatform: false),

    // Variables / profiles
    TaskKind(id: 'set_var', label: 'Set Variable', group: 'logic', description: 'Store key=value'),
    TaskKind(id: 'edit_var', label: 'Edit Variable', group: 'logic', description: 'Update variable'),
    TaskKind(id: 'del_var', label: 'Delete Variable', group: 'logic', description: 'Remove variable'),
    TaskKind(id: 'run_profile', label: 'Run Profile', group: 'logic', description: 'Execute ordered task list'),
    TaskKind(id: 'dialog', label: 'Yes/No Dialog', group: 'logic', description: 'Confirm before continue'),
    TaskKind(id: 'cond_time', label: 'Condition: Time', group: 'logic', description: 'Gate by time range'),
    TaskKind(id: 'cond_date', label: 'Condition: Date', group: 'logic', description: 'Gate by date'),
    TaskKind(id: 'cond_battery', label: 'Condition: Battery', group: 'logic', description: 'Gate by battery %'),
    TaskKind(id: 'cond_wifi', label: 'Condition: Wi-Fi', group: 'logic', description: 'Gate by Wi-Fi state'),

    // Misc
    TaskKind(id: 'alarm_set', label: 'Set Alarm', group: 'misc', description: 'AlarmClock intent'),
    TaskKind(id: 'alarm_in', label: 'Alarm In', group: 'misc', description: 'Alarm after N minutes'),
    TaskKind(id: 'timer_set', label: 'Set Timer', group: 'misc', description: 'Countdown timer'),
    TaskKind(id: 'insert_event', label: 'Calendar Event', group: 'misc', description: 'Insert calendar event'),
    TaskKind(id: 'change_wallpaper', label: 'Wallpaper', group: 'misc', description: 'Set wallpaper'),
    TaskKind(id: 'roll_dice', label: 'Roll Dice', group: 'misc', description: 'Random 1..N'),
    TaskKind(id: 'timestamp_file', label: 'Timestamp → File', group: 'misc', description: 'Append timestamp'),
    TaskKind(id: 'timezone', label: 'Time Zone', group: 'misc', description: 'Open timezone settings'),
    TaskKind(id: 'wear_notification', label: 'Wear Notification', group: 'misc', description: 'Wearable notification'),
  ];

  static TaskKind? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static List<String> get groups =>
      all.map((e) => e.group).toSet().toList()..sort();
}
