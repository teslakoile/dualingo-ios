//
//  AudioManager.swift
//  dualingo-ios
//
//  Created by Kyle Naranjo on 12/26/23.
//

import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published var isRecording = false
    @Published var recordedAudioURL: URL?
    @Published var isPlaying = false

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        setupRecorder()
    }
    
    func setupAudioSession() {
        do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                print("Audio session is set up for recording and playback.")
            } catch {
                print("Failed to set up the audio session: \(error.localizedDescription)")
            }
        }

    private func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }

        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("recording.wav")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
        } catch {
            print("Could not start audio recording: \(error)")
        }
    }

    func startRecording() {
        setupAudioSession()
            let audioFilename = generateUniqueFileName()

            let settings = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
                audioRecorder?.delegate = self
                audioRecorder?.record()
                isRecording = true
                print("Recording started at \(audioFilename)")
            } catch {
                print("Could not start audio recording: \(error.localizedDescription)")
            }
        }

    func stopRecording() {
            if isRecording {
                audioRecorder?.stop()
                isRecording = false
                recordedAudioURL = audioRecorder?.url
                if let url = recordedAudioURL, let audioData = try? Data(contentsOf: url) {
                    print("Recording stopped. Data length: \(audioData.count) bytes")
                } else {
                    print("Recording stopped but data is not available.")
                }
                audioRecorder = nil
            }
        }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
    
    private func getDocumentsDirectory() -> URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
    
    func reset() {
        stopRecording()
        recordedAudioURL = nil
    }
    
    private func generateUniqueFileName() -> URL {
            let timestamp = Date().timeIntervalSince1970
            let filename = "recording_\(timestamp).wav"
            return getDocumentsDirectory().appendingPathComponent(filename)
        }
    
    private func playRecordedAudio() {
            guard let url = recordedAudioURL else {
                print("Recorded audio URL is not available")
                return
            }

            do {
                audioPlayer?.stop()
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 5.0
                audioPlayer?.play()
                isPlaying = true
                print("Playing recorded audio")
            } catch {
                print("Could not play the recorded audio: \(error)")
                isPlaying = false
            }
        }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            isPlaying = false
            print("Playback finished. Success: \(flag)")
              // Set to false when playing ends
        }
}
