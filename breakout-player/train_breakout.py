import random
import time
from collections import deque
import os

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim

import memory_handler as mem
import reader


PROCESS_NAMES = ["dosbox-x.exe"]

CHECKPOINT_PATH = "breakout_checkpoint.pt"

AI_LEFT = 1
AI_RIGHT = 2
AI_SPACE = 3
AI_NONE = 0

STATE_SIZE = 5
ACTION_SIZE = 3

GAMMA = 0.98
LR = 1e-3
BATCH_SIZE = 64
MEMORY_SIZE = 20_000

EPSILON_START = 1.0
EPSILON_END = 0.05
EPSILON_DECAY = 0.995

BRICK_REWARD = 5.0
PADDLE_HIT_REWARD = 2.0
GAME_OVER_PENALTY = -20.0
SURVIVAL_REWARD = 0.01
ALIGNMENT_REWARD_MAX = 0.25
MOVE_CLOSER_REWARD = 0.05


class DQN(nn.Module):
    def __init__(self):
        super().__init__()

        self.net = nn.Sequential(
            nn.Linear(STATE_SIZE, 64),
            nn.ReLU(),
            nn.Linear(64, 64),
            nn.ReLU(),
            nn.Linear(64, ACTION_SIZE),
        )

    def forward(self, x):
        return self.net(x)


def choose_target_ball(active_balls):
    if not active_balls:
        return None

    # The lowest ball is usually the most dangerous
    return max(active_balls, key=lambda b: b["y"])


def state_to_vector(game_state):
    paddle_x = game_state["paddle"]["x"]
    active_balls = game_state["active_balls"]

    ball = choose_target_ball(active_balls)

    if ball is None:
        ball_x = 160
        ball_y = 170
        speed_x = 3
        speed_y = 2
    else:
        ball_x = ball["x"]
        ball_y = ball["y"]
        speed_x = ball["speed_x"]
        speed_y = ball["speed_y"]

    return np.array([
        paddle_x / 320.0,
        ball_x / 320.0,
        ball_y / 200.0,
        speed_x / 5.0,
        speed_y / 3.0,
    ], dtype=np.float32)


def action_to_ai_input(action):
    if action == 0:
        return AI_NONE
    if action == 1:
        return AI_LEFT
    if action == 2:
        return AI_RIGHT

    return AI_NONE


def get_ball_by_index(active_balls, index):
    for ball in active_balls:
        if ball["index"] == index:
            return ball
    return None


def compute_reward(old_state, new_state):
    reward = 0.0

    old_score = old_state["score"]
    new_score = new_state["score"]

    # 1. Reward destroying bricks
    bricks_destroyed = new_score - old_score
    if bricks_destroyed > 0:
        reward += bricks_destroyed * BRICK_REWARD

    # 2. Small survival reward
    reward += SURVIVAL_REWARD

    # 3. Big game-over penalty
    if new_state["game_over"] == 1:
        reward += GAME_OVER_PENALTY

    old_balls = old_state["active_balls"]
    new_balls = new_state["active_balls"]

    old_target = choose_target_ball(old_balls)
    new_target = choose_target_ball(new_balls)

    # 4. Reward paddle alignment with dangerous ball
    if new_target is not None:
        paddle_center = new_state["paddle"]["x"] + 7

        ball_x = new_target["x"]
        ball_y = new_target["y"]

        distance = abs(ball_x - paddle_center)

        # 1.0 when perfectly aligned, 0.0 when far away
        alignment = 1.0 - min(distance / 80.0, 1.0)

        # More important when ball is lower
        danger = ball_y / 200.0

        reward += alignment * danger * ALIGNMENT_REWARD_MAX

    # 5. Reward moving closer to the dangerous ball
    if old_target is not None and new_target is not None:
        old_paddle_center = old_state["paddle"]["x"] + 7
        new_paddle_center = new_state["paddle"]["x"] + 7

        old_distance = abs(old_target["x"] - old_paddle_center)
        new_distance = abs(new_target["x"] - new_paddle_center)

        if new_distance < old_distance:
            reward += MOVE_CLOSER_REWARD
        elif new_distance > old_distance:
            reward -= MOVE_CLOSER_REWARD

    # 6. Reward paddle hit
    # Detect a ball that was moving down and is now moving up near paddle area
    for old_ball in old_balls:
        new_ball = get_ball_by_index(new_balls, old_ball["index"])

        if new_ball is None:
            continue

        was_moving_down = old_ball["speed_y"] == 2
        now_moving_up = new_ball["speed_y"] == 1
        near_paddle = new_ball["y"] >= 160

        if was_moving_down and now_moving_up and near_paddle:
            reward += PADDLE_HIT_REWARD

    return reward


def train_step(model, target_model, optimizer, replay_memory):
    if len(replay_memory) < BATCH_SIZE:
        return

    batch = random.sample(replay_memory, BATCH_SIZE)

    states, actions, rewards, next_states, dones = zip(*batch)

    states = torch.tensor(np.array(states), dtype=torch.float32)
    actions = torch.tensor(actions, dtype=torch.int64).unsqueeze(1)
    rewards = torch.tensor(rewards, dtype=torch.float32)
    next_states = torch.tensor(np.array(next_states), dtype=torch.float32)
    dones = torch.tensor(dones, dtype=torch.float32)

    q_values = model(states).gather(1, actions).squeeze()

    with torch.no_grad():
        next_q_values = target_model(next_states).max(1)[0]
        targets = rewards + GAMMA * next_q_values * (1.0 - dones)

    loss = nn.functional.mse_loss(q_values, targets)

    optimizer.zero_grad()
    loss.backward()
    optimizer.step()


def wait_for_game_ready(handle, base):
    # Reset/start game using ai_input
    mem.write_u8(handle, base + reader.OFFSETS["ai_input"], AI_SPACE)
    time.sleep(0.2)

    state = reader.read_game_state(handle, base)

    if state["game_over"] == 1:
        mem.write_u8(handle, base + reader.OFFSETS["ai_input"], AI_SPACE)
        time.sleep(0.5)

    mem.write_u8(handle, base + reader.OFFSETS["ai_input"], AI_SPACE)
    time.sleep(0.2)

def save_checkpoint(model, target_model, optimizer, episode, steps, epsilon):
    torch.save({
        "model_state": model.state_dict(),
        "target_model_state": target_model.state_dict(),
        "optimizer_state": optimizer.state_dict(),
        "episode": episode,
        "steps": steps,
        "epsilon": epsilon,
    }, CHECKPOINT_PATH)

    print(f"Saved checkpoint: episode={episode}, steps={steps}, epsilon={epsilon:.3f}")

def load_checkpoint(model, target_model, optimizer):
    import os

    if not os.path.exists(CHECKPOINT_PATH):
        print("No checkpoint found. Starting from scratch.")
        return 0, 0, EPSILON_START

    checkpoint = torch.load(CHECKPOINT_PATH)

    model.load_state_dict(checkpoint["model_state"])
    target_model.load_state_dict(checkpoint["target_model_state"])
    optimizer.load_state_dict(checkpoint["optimizer_state"])

    episode = checkpoint["episode"]
    steps = checkpoint["steps"]
    epsilon = checkpoint["epsilon"]

    print(f"Loaded checkpoint: episode={episode}, steps={steps}, epsilon={epsilon:.3f}")

    return episode, steps, epsilon


def main():
    pid, process_name = mem.find_process_id(PROCESS_NAMES)
    print(f"Found process: {process_name} PID={pid}")

    handle = mem.open_process(pid)
    base = reader.find_breakout_base(handle)

    print(f"Breakout base address: 0x{base:X}")
    print(f"ai_input address:      0x{base + reader.OFFSETS['ai_input']:X}")

    model = DQN()
    target_model = DQN()

    optimizer = optim.Adam(model.parameters(), lr=LR)
    replay_memory = deque(maxlen=MEMORY_SIZE)

    episode, steps, epsilon = load_checkpoint(model, target_model, optimizer)

    wait_for_game_ready(handle, base)

    old_game_state = reader.read_game_state(handle, base)
    old_vector = state_to_vector(old_game_state)


    try:
        while True:
            steps += 1

            # Choose action
            if random.random() < epsilon:
                action = random.randint(0, ACTION_SIZE - 1)
            else:
                with torch.no_grad():
                    x = torch.tensor(old_vector, dtype=torch.float32).unsqueeze(0)
                    action = int(torch.argmax(model(x)).item())

            ai_input = action_to_ai_input(action)
            mem.write_u8(handle, base + reader.OFFSETS["ai_input"], ai_input)

            # Let game advance
            time.sleep(0.03)

            new_game_state = reader.read_game_state(handle, base)
            new_vector = state_to_vector(new_game_state)

            reward = compute_reward(old_game_state, new_game_state)
            done = new_game_state["game_over"] == 1

            replay_memory.append((
                old_vector,
                action,
                reward,
                new_vector,
                float(done),
            ))

            train_step(model, target_model, optimizer, replay_memory)

            old_game_state = new_game_state
            old_vector = new_vector

            if steps % 200 == 0:
                target_model.load_state_dict(model.state_dict())

            if steps % 100 == 0:
                print(
                    f"episode={episode} "
                    f"steps={steps} "
                    f"score={new_game_state['score']} "
                    f"balls={len(new_game_state['active_balls'])} "
                    f"epsilon={epsilon:.3f} "
                    f"reward={reward:.3f}"
                )

            if done:
                episode += 1
                epsilon = max(EPSILON_END, epsilon * EPSILON_DECAY)

                print(f"GAME OVER | episode={episode} score={new_game_state['score']} epsilon={epsilon:.3f}")

                save_checkpoint(model, target_model, optimizer, episode, steps, epsilon)

                # Reset game
                mem.write_u8(handle, base + reader.OFFSETS["ai_input"], AI_SPACE)
                time.sleep(0.5)

                # Start game
                mem.write_u8(handle, base + reader.OFFSETS["ai_input"], AI_SPACE)
                time.sleep(0.2)

                old_game_state = reader.read_game_state(handle, base)
                old_vector = state_to_vector(old_game_state)
    except KeyboardInterrupt:
        print("Saving model before exit...")
        save_checkpoint(model, target_model, optimizer, episode, steps, epsilon)
        print("Saved.")


if __name__ == "__main__":
    main()