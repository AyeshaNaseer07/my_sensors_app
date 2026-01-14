import 'package:flutter/material.dart';
import 'package:ui_design/App/modules/selfie_click/home_screen.dart';
import 'package:ui_design/App/modules/sensors/anti_theft/anti_theft_view.dart';
import 'package:ui_design/App/modules/sensors/bluetooth_sensor/bluetooth_view.dart';
import 'package:ui_design/App/modules/sensors/clap_whistle_detect/clap_detect_view.dart';
import 'package:ui_design/App/modules/sensors/headphone/headphone_view.dart';
import 'package:ui_design/App/modules/sensors/motion_sensor/motion_view.dart';
import 'package:ui_design/App/modules/sensors/power_sensor/power_view.dart';
import 'package:ui_design/App/modules/sensors/proximity_sensor/proximity_sensor_view.dart';
import 'package:ui_design/App/modules/sensors/wifi_sensor/wifi_sensor_view.dart';

class SensorHubPage extends StatelessWidget {
  const SensorHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sensors Hub"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          sensorCard(
            context,
            "Anti-theft",
            Icons.compass_calibration_outlined,
            Colors.blueGrey,
            AntiTheftView(),
          ),
          sensorCard(
            context,
            "Proximity",
            Icons.sensors,
            Colors.purple,
            ProximitySensorView(),
          ),
          sensorCard(
            context,
            "Motion",
            Icons.motion_photos_on,
            Colors.red,
            MotionSensorView(),
          ),
          sensorCard(
            context,
            "Wi-Fi",
            Icons.wifi,
            Colors.blue,
            WifiAlarmPage(),
          ),
          sensorCard(
            context,
            "Bluetooth",
            Icons.bluetooth,
            Colors.indigo,
            BluetoothAlarmPage(),
          ),
          sensorCard(
            context,
            "Charging",
            Icons.battery_charging_full,
            Colors.green,
            const ChargerAlarmPage(),
          ),
          sensorCard(
            context,
            "Headphones",
            Icons.headset,
            Colors.orange,
            const HeadphoneSensorPage(),
          ),
          sensorCard(
            context,
            "Clap and Whistle",
            Icons.surround_sound_outlined,
            Colors.black,
            const ClapDetectView(),
          ),
          sensorCard(
            context,
            "View Unauthorized Attempts",
            Icons.person_off_outlined,
            Colors.blueGrey,
            const HomeViewScreen(),
          ),
        ],
      ),
    );
  }

  Widget sensorCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListTile(
        leading: Icon(icon, size: 32, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }
}
