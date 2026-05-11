import memory_handler as mem
import reader
import time

PROCESS_NAMES = ["dosbox-x.exe"]

AI_INPUT_OFFSET = 0x4DB

AI_LEFT = 1
AI_RIGHT = 2
AI_SPACE = 3
AI_NONE = 0

pid, process_name = mem.find_process_id(PROCESS_NAMES)
print(f"Found process: {process_name} PID={pid}")

handle = mem.open_process(pid)

try:
    base = reader.find_breakout_base(handle)

    print()
    print(f"Breakout base address: 0x{base:X}")
    print(f"ai_input address:      0x{base + AI_INPUT_OFFSET:X}")
    print(f"pos_x address:         0x{base + reader.OFFSETS['pos_x']:X}")
    print(f"score address:         0x{base + reader.OFFSETS['score']:X}")
    print(f"game_over address:     0x{base + reader.OFFSETS['game_over']:X}")

    # Start the game
    mem.write_u8(handle, base + AI_INPUT_OFFSET, AI_SPACE)
    time.sleep(0.2)

    while True:
        state = reader.read_game_state(handle, base)

        paddle_x = state["paddle"]["x"]
        balls = state["active_balls"]
        game_over = state["game_over"]

        reader.print_state(state)

        if game_over == 1:
            print("Game over. Resetting...")
            time.sleep(0.5)
            mem.write_u8(handle, base + AI_INPUT_OFFSET, AI_SPACE)
            continue

        if not balls:
            # no active balls yet, start game
            mem.write_u8(handle, base + AI_INPUT_OFFSET, AI_SPACE)
            time.sleep(0.2)
            continue

        # Pick the lowest active ball, usually the most urgent one
        target_ball = max(balls, key=lambda b: b["y"])
        ball_x = target_ball["x"]

        paddle_center = paddle_x + 7  # size_x = 14

        if ball_x < paddle_center - 2:
            action = AI_LEFT
        elif ball_x > paddle_center + 2:
            action = AI_RIGHT
        else:
            action = AI_NONE

        mem.write_u8(handle, base + AI_INPUT_OFFSET, action)

        # Lower delay = more responsive AI
        time.sleep(0.03)

finally:
    mem.kernel32.CloseHandle(handle)