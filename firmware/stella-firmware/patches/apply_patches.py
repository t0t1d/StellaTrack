#!/usr/bin/env python3
"""Apply StellaUWB library patches to .pio/libdeps/ copies."""

import os
import sys

ENVS = ["stella", "stella-diag"]
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PATCHES = [
    {
        "file": "StellaUWB/src/uwbapps/NearbySessionManager.cpp",
        "replacements": [
            (
                "    //NearbySessionManager::instance().handleStopSession(central);",
                "    NearbySessionManager::instance().handleStopSession(central);",
            ),
            (
                "    case kMsg_ConfigureAndStart:\n"
                "    {\n"
                "        nearbySession.sessionState(notStarted);",
                "    case kMsg_ConfigureAndStart:\n"
                "    {\n"
                "        if (nearbySession.sessionState() == Started)\n"
                "        {\n"
                "            UWBHAL.Log_I(\"Stopping active session before reconfigure\");\n"
                "            nearbySession.stop();\n"
                "            nearbySession.sessionState(notStarted);\n"
                "        }\n"
                "        if (nearbySession.sessionState() == notStarted)\n"
                "        {\n"
                "            nearbySession.stop();\n"
                "            nearbySession.deInit();\n"
                "            nearbySession.sessionState(notCreated);\n"
                "        }\n"
                "        nearbySession.sessionState(notStarted);",
            ),
            (
                "                    const uint8_t tmpData[50] = {0};\n"
                "                    accessoryConfigDataChar.writeValue(tmpData, 50);//neds to be fixed",
                "                    uint8_t *cachedCfg = nearbySession.config();\n"
                "                    uint16_t cachedLen = nearbySession.configLen();\n"
                "                    if (cachedLen > 1) {\n"
                "                        accessoryConfigDataChar.writeValue(cachedCfg + 1, cachedLen - 1);\n"
                "                    }",
            ),
            (
                "        if (nearbySession.configIOS() == uwb::Status::SUCCESS)\n"
                "        {\n"
                "            uint8_t *BLEmessage_iOS = nearbySession.config();\n"
                "            uint16_t cfgLen = nearbySession.configLen();",
                "        bool configOk = false;\n"
                "        if (nearbySession.sessionState() == Started && nearbySession.configLen() > 1) {\n"
                "            UWBHAL.Log_I(\"Re-sending cached config (session active)\");\n"
                "            configOk = true;\n"
                "        } else {\n"
                "            configOk = (nearbySession.configIOS() == uwb::Status::SUCCESS);\n"
                "        }\n"
                "        if (configOk)\n"
                "        {\n"
                "            uint8_t *BLEmessage_iOS = nearbySession.config();\n"
                "            uint16_t cfgLen = nearbySession.configLen();",
            ),
        ],
    },
    {
        "file": "StellaUWB/src/uwbapps/NearbySession.hpp",
        "replacements": [
            (
                "UWBHAL.getUwbConfigData_iOS(uwb::DeviceRole::INITIATOR,",
                "UWBHAL.getUwbConfigData_iOS(uwb::DeviceRole::RESPONDER,",
            ),
            (
                "profInfo.device_role = uwb::DeviceRole::INITIATOR;",
                "profInfo.device_role = uwb::DeviceRole::RESPONDER;",
            ),
            (
                "profInfo.device_type = uwb::DeviceType::CONTROLLER;",
                "profInfo.device_type = uwb::DeviceType::CONTROLEE;",
            ),
        ],
    },
]


def apply():
    ok = True
    for env in ENVS:
        for patch in PATCHES:
            path = os.path.join(BASE, ".pio", "libdeps", env, patch["file"])
            if not os.path.isfile(path):
                print(f"SKIP  {env}/{patch['file']} (not found)")
                continue
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            changed = False
            for old, new in patch["replacements"]:
                if new in content:
                    continue  # already applied
                if old in content:
                    content = content.replace(old, new, 1)
                    changed = True
                else:
                    print(f"WARN  {env}/{patch['file']}: pattern not found: {old[:60]}...")
                    ok = False
            if changed:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"PATCH {env}/{patch['file']}")
            else:
                print(f"OK    {env}/{patch['file']} (already patched)")
    return ok


if __name__ == "__main__":
    if not apply():
        print("\nSome patches could not be applied.", file=sys.stderr)
        sys.exit(1)
    print("\nAll patches applied.")
