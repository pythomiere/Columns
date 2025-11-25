import json
import math

def json_to_assembly(filename):
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
    except json.JSONDecodeError:
        print("Error: not valid JSON")
        return

    track = data['tracks'][0]
    notes = track['notes']
    instrument = track['instrument']['number']
    count = len(notes)
    
    midi_pitches = [n['midi'] for n in notes]
    
    durations = [int(round(n['duration'] * 1000)) for n in notes]

    print(f"# Music configuration")
    print(f"MUSIC_ENABLED:        .word 1        # 1=play, 0=stop")
    print(f"MUSIC_NOTE_IDX:       .word 0        # current note index")
    print(f"MUSIC_TIME_LEFT_MS:   .word 0        # ms until next note")
    print(f"MUSIC_NOTE_COUNT:     .word {count}")
    print(f"MUSIC_INSTRUMENT:     .word {instrument}")
    print(f"MUSIC_VOLUME:         .word 100      # Default volume")
    print(f"")

    def print_array_data(label, data_list):
        print(f"{label}:")
        chunk_size = 8
        for i in range(0, len(data_list), chunk_size):
            chunk = data_list[i:i + chunk_size]
            line_str = ", ".join(map(str, chunk))
            print(f"    .word {line_str}")
        print("")

    print("# MIDI pitches")
    print_array_data("MUSIC_THEME_NOTES", midi_pitches)

    print("# Durations in milliseconds")
    print_array_data("MUSIC_THEME_DURS", durations)

json_to_assembly('clotho.json')