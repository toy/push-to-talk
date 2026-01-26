//
//  AppDelegate.swift
//  PushToTalk
//
//  Created by Ahmy Yulrizka on 17/03/15.
//  Copyright (c) 2015 yulrizka. All rights reserved.
//

import Cocoa
import AudioToolbox
import Foundation
import AVFoundation
import Carbon.HIToolbox.Events

@main
class AppDelegate: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate {
  @IBOutlet weak var statusMenu: NSMenu!
  @IBOutlet weak var menuItemToggle: NSMenuItem!

  var pushToTalk = true
  var pushed = false
  var muted: Bool?

  var talkIcon: NSImage?
  var muteIcon: NSImage?

  var apUp: AVAudioPlayer?
  var apDown: AVAudioPlayer?

  let statusItem = NSStatusBar.system.statusItem(withLength: -1)

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    talkIcon = NSImage(named: "talk")
    muteIcon = NSImage(named: "mute")
    muteIcon?.isTemplate = true

    apUp = loadPlayer("sounds/up")
    apDown = loadPlayer("sounds/down")

    statusItem.menu = statusMenu
    menuItemToggle.keyEquivalent = "🌐"
    menuItemToggle.keyEquivalentModifierMask = .shift

    updateActionTitle()
    toggleMute(true)

    // handle when application is in background
    NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: handleFlagChangedEvent)

    // handle when application is in foreground
    NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { theEvent -> NSEvent? in
      self.handleFlagChangedEvent(theEvent)
      return theEvent
    })
  }

  func applicationWillTerminate(_ notification: Notification) {
    toggleMute(false)
  }

  @IBAction func toggleAction(_ sender: NSMenuItem) {
    pushToTalk = !pushToTalk
    updateActionTitle()
    updateMute()
  }

  @IBAction func menuItemQuitAction(_ sender: NSMenuItem) {
    if pushToTalk {
      apUp?.delegate = self
      apUp?.play()
    } else {
      quit()
    }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    quit()
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  func handleFlagChangedEvent(_ theEvent: NSEvent) {
    if theEvent.keyCode != kVK_Function { return }

    pushed = theEvent.modifierFlags.contains(.function)

    if pushed && theEvent.modifierFlags.contains(.shift) {
      pushToTalk = !pushToTalk
      updateActionTitle()
    }

    updateMute()
  }

  func updateMute() {
    toggleMute(pushed != pushToTalk)
  }

  func updateActionTitle() {
    menuItemToggle.title = pushToTalk ? "Disable / push-to-mute" : "Enable / push-to-talk"
    (pushToTalk ? apDown : apUp)?.play()
  }

  func toggleMute(_ mute: Bool) {
    if muted != mute {
      muted = mute

      setDefaultInputDeviceMute(mute)
      statusItem.button?.image = mute ? muteIcon : talkIcon
    }
  }

  func setDefaultInputDeviceMute(_ mute: Bool) {
    // https://github.com/paulreimer/ofxAudioFeatures/blob/master/src/ofxAudioDeviceControl.mm
    var defaultInputDeviceId = AudioDeviceID(0)
    getDefaultInputDevice(&defaultInputDeviceId)

    var address = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioDevicePropertyMute),
      mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeInput),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

    let size = UInt32(MemoryLayout<UInt32>.size)
    var muteValue: UInt32 = mute ? 1 : 0

    let err = AudioObjectSetPropertyData(defaultInputDeviceId, &address, 0, nil, size, &muteValue)

    if (err != kAudioHardwareNoError) {
      NSLog("Error setting audio object property data #%d", err)
    }
  }

  func getDefaultInputDevice(_ defaultInputDeviceID: inout UInt32) {
    defaultInputDeviceID = AudioDeviceID(0)
    var defaultInputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultInputDeviceID))

    var getDefaultInputDevicePropertyAddress = AudioObjectPropertyAddress(
      mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultInputDevice),
      mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
      mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMaster))

    let err = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &getDefaultInputDevicePropertyAddress,
      0,
      nil,
      &defaultInputDeviceIDSize,
      &defaultInputDeviceID)

    if (err != kAudioHardwareNoError) {
      NSLog("Error setting audio object property data #%d", err)
    }
  }

  func loadPlayer(_ name: String) -> AVAudioPlayer? {
    if let path = Bundle.main.path(forResource: name, ofType: "mp3") {
      let ap: AVAudioPlayer? = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
      ap?.volume = 0.5
      return ap
    } else {
      return nil
    }
  }
}
