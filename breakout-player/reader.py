import memory_handler as mem


# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

SIGNATURE = b"BREAKOUT MEMORY START"
MIN_VALID_ADDRESS = 0x10000000

MAX_PROJECTILES = 25
BRICK_COUNT = 348

OFFSETS = {
    "pos_x": 0x015,
    "pos_y": 0x017,

    "bricks": 0x02B,
    "brick_type": 0x187,

    "proj_pos_x": 0x2EF,
    "proj_pos_y": 0x321,
    "proj_speed_x": 0x353,
    "proj_speed_y": 0x385,
    "proj_steps_x": 0x3B7,
    "proj_steps_y": 0x3E9,
    "proj_active": 0x41B,

    "game_started": 0x4BD,
    "score": 0x4D3,
    "game_over": 0x4D5,
    "score_digits": 0x4D7,
    "ai_input": 0x4DB,
}

def is_valid_breakout_block(handle, base):
    try:
        pos_x = mem.read_u16(handle, base + OFFSETS["pos_x"])
        pos_y = mem.read_u16(handle, base + OFFSETS["pos_y"])
        score = mem.read_u16(handle, base + OFFSETS["score"])
        game_over = mem.read_u16(handle, base + OFFSETS["game_over"])

        if not (0 <= pos_x <= 319):
            return False

        if not (0 <= pos_y <= 199):
            return False

        if not (0 <= score <= 5000):
            return False

        if game_over not in (0, 1):
            return False

        signature_check = mem.read_bytes(handle, base, len(SIGNATURE))
        if signature_check != SIGNATURE:
            return False

        return True

    except OSError:
        return False


def find_breakout_base(handle):
    print("Scanning DOSBox-X memory for BREAKOUT MEMORY START...")

    candidates = []

    for region_base, region_size in mem.iter_memory_regions(handle, MIN_VALID_ADDRESS):
        matches = mem.scan_region_for_signature(
            handle,
            region_base,
            region_size,
            SIGNATURE,
        )

        for match in matches:
            if match < MIN_VALID_ADDRESS:
                continue

            if is_valid_breakout_block(handle, match):
                candidates.append(match)
                print(f"Valid candidate found: 0x{match:X}")

    if not candidates:
        raise RuntimeError("Could not find valid Breakout memory block")

    # Usually the live block is the first valid high address.
    return candidates[0]


def read_game_state(handle, base):
    pos_x = mem.read_u16(handle, base + OFFSETS["pos_x"])
    pos_y = mem.read_u16(handle, base + OFFSETS["pos_y"])

    score = mem.read_u16(handle, base + OFFSETS["score"])
    game_over = mem.read_u16(handle, base + OFFSETS["game_over"])

    proj_x = mem.read_u16_array(
        handle,
        base + OFFSETS["proj_pos_x"],
        MAX_PROJECTILES,
    )

    proj_y = mem.read_u16_array(
        handle,
        base + OFFSETS["proj_pos_y"],
        MAX_PROJECTILES,
    )

    proj_speed_x = mem.read_u16_array(
        handle,
        base + OFFSETS["proj_speed_x"],
        MAX_PROJECTILES,
    )

    proj_speed_y = mem.read_u16_array(
        handle,
        base + OFFSETS["proj_speed_y"],
        MAX_PROJECTILES,
    )

    proj_active = mem.read_u16_array(
        handle,
        base + OFFSETS["proj_active"],
        MAX_PROJECTILES,
    )

    bricks = mem.read_u8_array(
        handle,
        base + OFFSETS["bricks"],
        BRICK_COUNT,
    )

    active_balls = []

    for i in range(MAX_PROJECTILES):
        if proj_active[i] == 1:
            active_balls.append({
                "index": i,
                "x": proj_x[i],
                "y": proj_y[i],
                "speed_x": proj_speed_x[i],
                "speed_y": proj_speed_y[i],
            })

    return {
        "paddle": {
            "x": pos_x,
            "y": pos_y,
        },
        "score": score,
        "game_over": game_over,
        "active_balls": active_balls,
        "bricks_alive": sum(1 for b in bricks if b == 1),
        "bricks": bricks,
    }


def print_state(state):
    print()
    print("-" * 60)
    print(f"Paddle: x={state['paddle']['x']} y={state['paddle']['y']}")
    print(f"Score: {state['score']}")
    print(f"Game over: {state['game_over']}")
    print(f"Bricks alive: {state['bricks_alive']}")
    print(f"Active balls: {len(state['active_balls'])}")

    for ball in state["active_balls"][:10]:
        print(
            f"  Ball {ball['index']:02d}: "
            f"x={ball['x']:3d} y={ball['y']:3d} "
            f"vx={ball['speed_x']} vy={ball['speed_y']}"
        )

    if len(state["active_balls"]) > 10:
        print(f"  ... {len(state['active_balls']) - 10} more balls")
