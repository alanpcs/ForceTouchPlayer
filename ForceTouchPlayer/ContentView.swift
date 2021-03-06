import SwiftUI

let timerClockHz = 1000.0
let timerInterval = 1.0 / timerClockHz

struct ContentView: View {
    
    let songsList: [Song]
    
    private let timer = Timer.publish(every: timerInterval, tolerance: timerInterval, on: .main, in: .common).autoconnect()
    
    @State private var timerEnabled = false
    @State private var skippedTicksCount = 0
    
    @State private var currentNoteIndex: Int = 0;
    @State private var currentNote: Note?
    @State private var currentNoteEndTime: Date?
    
    @State private var tempo = 144.0
    @State private var currentSongIndex: Int = 0
    
    init(songsRepository: SongsRepository) {
        self.songsList = songsRepository.listSongs()
    }
    
    var body: some View {
        let tempoStr = String(format: "%.1f", self.tempo).padding(toLength: 5, withPad: " ", startingAt: 0);

        return HStack {
            Spacer()
                .frame(width: 64.0)
            VStack {
                Spacer()
                Picker(selection: $currentSongIndex.onChange(handlePickerChange), label: Text("Song:").frame(width: 130, alignment: .leading)) {
                    ForEach(0 ..< songsList.count, id: \.self) {
                        Text(self.songsList[$0].name).tag($0)
                    }
                }
                HStack {
                    Text("Tempo: \(tempoStr) BPM").frame(width: 130, alignment: .leading)
                    Slider(value: $tempo, in: 40...200, step: 4)
                }
                Spacer()
                Text("Don't take your finger off of the trackpad!")
                Button(action: self.toggleTimer) {
                    Text(timerEnabled ? "Stop" : "Play")
                }
                .padding()
                Spacer()
            }
            Spacer()
                .frame(width: 64.0)
        }
        .frame(minWidth: 480, maxWidth: 600, minHeight: 300, maxHeight: 400)
        .onReceive(timer) {
            time in
            self.playTick()
        }
    }
    
    func handlePickerChange(_ index: Int) {
        self.tempo = songsList[currentSongIndex].defaultTempo
        self.stop()
    }
    
    func toggleTimer() {
        if (self.timerEnabled) {
            self.stop()
        } else {
            self.start()
        }
    }
    
    func start() {
        self.timerEnabled = true
        self.enqueueInitialNote()
    }
    
    func stop() {
        self.timerEnabled = false
        self.currentNoteIndex = 0
        self.currentNote = nil
        self.currentNoteEndTime = nil
        self.skippedTicksCount = 0
    }
    
    func playTick() {
        guard timerEnabled else { return }
        guard let currentNote = self.currentNote else { return }
        guard let currentNoteEndTime = self.currentNoteEndTime else { return }
        
        if (Date() > currentNoteEndTime) {
            self.enqueueNextNote()
        }
        
        self.playTickOfTone(frequency: currentNote.frequency)
    }
    
    func enqueueInitialNote() {
        self.currentNoteIndex = 0
        self.enqueueNote()
    }
    
    func enqueueNextNote() {
        self.currentNoteIndex += 1
        self.enqueueNote()
    }
    
    func enqueueNote() {
        guard let note = self.loadNote(index: self.currentNoteIndex) else {
            // End of song
            self.stop()
            return
        }
        
        // Time it takes to play a note with 4 beats
        // (1min / tempo (bpm))
        let baseDuration = (60000.0) / tempo
        
        let noteDuration = baseDuration * note.value
        
        self.skippedTicksCount = 0
        self.currentNote = note;
        let currentNoteEndTime = Date().addingTimeInterval(noteDuration / 1000.0)
        self.currentNoteEndTime = currentNoteEndTime
    }
    
    func loadNote(index: Int) -> Note? {
        let currentSong = self.songsList[currentSongIndex]
        
        if (index >= currentSong.notes.endIndex) {
            return nil
        }
        
        return currentSong.notes[index]
    }
    
    /// Software PWM
    /// Only performs haptic feedback in fractions of the timer frequency
    /// Example: If timer has frequency of 1000 Hz and we want to play at 100Hz,
    /// we need to skip 9 clock ticks. This way, we play once every 10 ticks (1000/10 = 100)
    func playTickOfTone(frequency: Double) {
        if (frequency == 0) {
            return;
        }
        let clockTicksPerToneTick = Int(timerClockHz / frequency)
        let clockTicksToSkip = clockTicksPerToneTick - 1
        
        if (self.skippedTicksCount < clockTicksToSkip) {
            self.skippedTicksCount += 1
            return
        }
        
        self.performHapticFeedback()
        self.skippedTicksCount = 0
    }
    
    func performHapticFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            NSHapticFeedbackManager.FeedbackPattern.generic,
            performanceTime: NSHapticFeedbackManager.PerformanceTime.now)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(songsRepository: SongsRepository())
    }
}
