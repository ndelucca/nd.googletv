# TCL TV with Flauncher Setup Guide (Fedora)

## Quick TV Preparation (Do This First on Your TV)

**Enable Developer Mode:**
- Go to Settings > System > About
- Click on "Android TV OS build" **7 times**
- You'll see "You are now a developer"

**Enable ADB Debugging:**
- Go to Settings > System > Developer options
- Turn ON "USB debugging"
- Turn ON "Network debugging" or "ADB over network" (if available)

**Get Your TV's IP Address:**
- Go to Settings > Network & Internet > Your WiFi network
- Note down the IP address (e.g., 192.168.1.100)

---

## Steps from Your Fedora PC

### 1. Install ADB Tools

```bash
sudo dnf install android-tools
```

Verify installation:
```bash
adb version
```

### 2. Connect to Your TV via ADB

```bash
# Replace 192.168.1.100 with your TV's actual IP address
adb connect 192.168.1.100:5555
```

You should see: `connected to 192.168.1.100:5555`

**On your TV:** A popup will appear asking to allow USB debugging. Select **"Always allow from this computer"** and click **OK**.

Verify the connection:
```bash
adb devices
```

You should see something like:
```
List of devices attached
192.168.1.100:5555    device
```

### 3. Download Flauncher

```bash
# Navigate to your working directory
cd ~/dev/google_tv

# Download the latest Flauncher APK
wget https://github.com/flauncher/flauncher/releases/latest/download/flauncher.apk
```

Or download a specific version:
```bash
wget https://github.com/flauncher/flauncher/releases/download/v1.4.0/flauncher.apk
```

### 4. Install Flauncher on Your TV

```bash
adb install flauncher.apk
```

You should see: `Success`

### 5. Set Flauncher as Default Launcher

```bash
# Disable the Google TV Launcher
adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx

# If the above doesn't work, try this for older versions:
adb shell pm disable-user --user 0 com.google.android.tvlauncher

# Grant necessary permissions to Flauncher
adb shell pm grant me.efesser.flauncher android.permission.WRITE_SECURE_SETTINGS

# Set Flauncher as the default home launcher
adb shell cmd package set-home-activity me.efesser.flauncher/.activities.HomeActivity
```

### 6. Verify It's Working

```bash
adb shell cmd shortcut get-default-launcher
```

Should return: `me.efesser.flauncher`

Now press the **Home button** on your TV remote - you should see Flauncher instead of Google TV!

---

## Troubleshooting

### ADB Connection Issues

**If connection fails:**
```bash
# Kill and restart ADB server
adb kill-server
adb start-server

# Try connecting again
adb connect 192.168.1.100:5555
```

**If connection keeps disconnecting:**
- Make sure your TV doesn't go to sleep (Settings > Display & Sound > Screen saver)
- Some routers have aggressive power-saving features; try connecting both devices to 5GHz WiFi

**Check if firewall is blocking:**
```bash
sudo firewall-cmd --list-all
```

If needed, allow ADB port:
```bash
sudo firewall-cmd --permanent --add-port=5555/tcp
sudo firewall-cmd --reload
```

### Flauncher Issues

**If Flauncher crashes or doesn't appear:**
```bash
# Clear Flauncher data and reinstall
adb shell pm clear me.efesser.flauncher
adb uninstall me.efesser.flauncher
adb install flauncher.apk

# Then set it as default again
adb shell pm grant me.efesser.flauncher android.permission.WRITE_SECURE_SETTINGS
adb shell cmd package set-home-activity me.efesser.flauncher/.activities.HomeActivity
```

**To go back to Google Launcher:**
```bash
adb shell pm enable com.google.android.apps.tv.launcherx
adb shell cmd package set-home-activity com.google.android.apps.tv.launcherx/.MainActivity
```

---

## Optional: Connecting to Google Home

If you also want to control your TV via Google Home:

1. Open **Google Home app** on your phone
2. Tap **+** > **Set up device** > **Works with Google**
3. Search for "TCL" and follow the pairing steps

Your TV should also appear automatically if it has Google TV built-in.

---

## Complete Command Sequence (Copy & Paste)

```bash
# Install ADB
sudo dnf install android-tools

# Connect to TV (replace with your TV's IP)
adb connect 192.168.1.100:5555

# Download Flauncher
cd ~/dev/google_tv
wget https://github.com/flauncher/flauncher/releases/latest/download/flauncher.apk

# Install and configure
adb install flauncher.apk
adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx
adb shell pm grant me.efesser.flauncher android.permission.WRITE_SECURE_SETTINGS
adb shell cmd package set-home-activity me.efesser.flauncher/.activities.HomeActivity

# Verify
adb shell cmd shortcut get-default-launcher
```

---

## Updating Flauncher Later

```bash
# Download new version
cd ~/dev/google_tv
wget https://github.com/flauncher/flauncher/releases/latest/download/flauncher.apk

# Reinstall (keeps your settings)
adb install -r flauncher.apk
```
