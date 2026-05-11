import ctypes
import struct
from ctypes import wintypes


# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

PROCESS_NAMES = [
    "dosbox-x.exe",
]

SIGNATURE = b"BREAKOUT MEMORY START"
MIN_VALID_ADDRESS = 0x10000000

MAX_PROJECTILES = 25
BRICK_COUNT = 348

OFFSETS = {
    "pos_x": 0x015,
    "pos_y": 0x017,

    "bricks": 0x02B,
    "brick_type": 0x187,

    "proj_pos_x": 0x301,
    "proj_pos_y": 0x333,
    "proj_speed_x": 0x365,
    "proj_speed_y": 0x397,
    "proj_steps_x": 0x3C9,
    "proj_steps_y": 0x3FB,
    "proj_active": 0x42D,

    "score": 0x4D3,
    "game_over": 0x4D5,
    "score_digits": 0x4D7,
}


# ------------------------------------------------------------
# WINDOWS CONSTANTS
# ------------------------------------------------------------

PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_VM_READ = 0x0010
PROCESS_VM_WRITE = 0x0020
PROCESS_VM_OPERATION = 0x0008

MEM_COMMIT = 0x1000

PAGE_NOACCESS = 0x01
PAGE_GUARD = 0x100

TH32CS_SNAPPROCESS = 0x00000002
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value


kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)


# ------------------------------------------------------------
# STRUCTS
# ------------------------------------------------------------

class PROCESSENTRY32(ctypes.Structure):
    _fields_ = [
        ("dwSize", wintypes.DWORD),
        ("cntUsage", wintypes.DWORD),
        ("th32ProcessID", wintypes.DWORD),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", wintypes.DWORD),
        ("cntThreads", wintypes.DWORD),
        ("th32ParentProcessID", wintypes.DWORD),
        ("pcPriClassBase", wintypes.LONG),
        ("dwFlags", wintypes.DWORD),
        ("szExeFile", ctypes.c_char * 260),
    ]


class MEMORY_BASIC_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BaseAddress", ctypes.c_void_p),
        ("AllocationBase", ctypes.c_void_p),
        ("AllocationProtect", wintypes.DWORD),
        ("RegionSize", ctypes.c_size_t),
        ("State", wintypes.DWORD),
        ("Protect", wintypes.DWORD),
        ("Type", wintypes.DWORD),
    ]


# ------------------------------------------------------------
# WINAPI SETUP
# ------------------------------------------------------------

kernel32.CreateToolhelp32Snapshot.argtypes = [
    wintypes.DWORD,
    wintypes.DWORD,
]
kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE

kernel32.Process32First.argtypes = [
    wintypes.HANDLE,
    ctypes.POINTER(PROCESSENTRY32),
]
kernel32.Process32First.restype = wintypes.BOOL

kernel32.Process32Next.argtypes = [
    wintypes.HANDLE,
    ctypes.POINTER(PROCESSENTRY32),
]
kernel32.Process32Next.restype = wintypes.BOOL

kernel32.OpenProcess.argtypes = [
    wintypes.DWORD,
    wintypes.BOOL,
    wintypes.DWORD,
]
kernel32.OpenProcess.restype = wintypes.HANDLE

kernel32.ReadProcessMemory.argtypes = [
    wintypes.HANDLE,
    ctypes.c_void_p,
    ctypes.c_void_p,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t),
]
kernel32.ReadProcessMemory.restype = wintypes.BOOL

kernel32.WriteProcessMemory.argtypes = [
    wintypes.HANDLE,
    ctypes.c_void_p,
    ctypes.c_void_p,
    ctypes.c_size_t,
    ctypes.POINTER(ctypes.c_size_t),
]
kernel32.WriteProcessMemory.restype = wintypes.BOOL

kernel32.VirtualQueryEx.argtypes = [
    wintypes.HANDLE,
    ctypes.c_void_p,
    ctypes.POINTER(MEMORY_BASIC_INFORMATION),
    ctypes.c_size_t,
]
kernel32.VirtualQueryEx.restype = ctypes.c_size_t

kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
kernel32.CloseHandle.restype = wintypes.BOOL


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

def raise_last_error(message: str):
    error = ctypes.get_last_error()
    raise OSError(error, f"{message}. WinError={error}")


def list_processes():
    snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)

    if snapshot == INVALID_HANDLE_VALUE:
        raise_last_error("CreateToolhelp32Snapshot failed")

    try:
        entry = PROCESSENTRY32()
        entry.dwSize = ctypes.sizeof(PROCESSENTRY32)

        if not kernel32.Process32First(snapshot, ctypes.byref(entry)):
            raise_last_error("Process32First failed")

        while True:
            pid = entry.th32ProcessID
            name = entry.szExeFile.decode(errors="ignore")
            yield pid, name

            if not kernel32.Process32Next(snapshot, ctypes.byref(entry)):
                break

    finally:
        kernel32.CloseHandle(snapshot)


def find_process_id(names):
    wanted = {name.lower() for name in names}

    for pid, name in list_processes():
        if name.lower() in wanted:
            return pid, name

    raise RuntimeError(
        f"Could not find DOSBox process. Looked for: {', '.join(names)}"
    )


def open_process(pid):
    handle = kernel32.OpenProcess(
        PROCESS_QUERY_INFORMATION 
        | PROCESS_VM_READ
        | PROCESS_VM_WRITE
        | PROCESS_VM_OPERATION,
        False,
        pid,
    )

    if not handle:
        raise_last_error("OpenProcess failed")

    return handle


def read_bytes(handle, address, size):
    buffer = ctypes.create_string_buffer(size)
    bytes_read = ctypes.c_size_t(0)

    ok = kernel32.ReadProcessMemory(
        handle,
        ctypes.c_void_p(address),
        buffer,
        size,
        ctypes.byref(bytes_read),
    )

    if not ok:
        raise_last_error(f"ReadProcessMemory failed at 0x{address:X}")

    return buffer.raw[:bytes_read.value]

def write_bytes(handle, address, data: bytes) -> int:
    buffer = ctypes.create_string_buffer(data)
    bytes_written = ctypes.c_size_t(0)

    ok = kernel32.WriteProcessMemory(
        handle,
        ctypes.c_void_p(address),
        buffer,
        len(data),
        ctypes.byref(bytes_written),
    )

    if not ok:
        raise_last_error(f"WriteProcessMemory failed at 0x{address:X}")

    return bytes_written.value

def try_read_bytes(handle, address, size):
    try:
        return read_bytes(handle, address, size)
    except OSError:
        return None


def read_u16(handle, address):
    data = read_bytes(handle, address, 2)
    return struct.unpack("<H", data)[0]


def read_u8(handle, address):
    data = read_bytes(handle, address, 1)
    return data[0]


def read_u16_array(handle, address, count):
    data = read_bytes(handle, address, count * 2)
    return list(struct.unpack("<" + "H" * count, data))


def read_u8_array(handle, address, count):
    data = read_bytes(handle, address, count)
    return list(data)

def write_u8(handle, address, value):
    write_bytes(handle, address, bytes([value & 0xFF]))


def is_readable_region(mbi):
    if mbi.State != MEM_COMMIT:
        return False

    if mbi.Protect & PAGE_GUARD:
        return False

    if mbi.Protect & PAGE_NOACCESS:
        return False

    return True


def iter_memory_regions(handle, min_address=0):
    address = min_address
    mbi = MEMORY_BASIC_INFORMATION()

    max_address = 0x7FFFFFFFFFFF

    while address < max_address:
        result = kernel32.VirtualQueryEx(
            handle,
            ctypes.c_void_p(address),
            ctypes.byref(mbi),
            ctypes.sizeof(mbi),
        )

        if result == 0:
            address += 0x10000
            continue

        base = mbi.BaseAddress or 0
        size = mbi.RegionSize

        if size == 0:
            address += 0x10000
            continue

        if is_readable_region(mbi):
            yield base, size

        address = base + size


def scan_region_for_signature(handle, base, size, signature):
    matches = []

    chunk_size = 1024 * 1024
    overlap = len(signature) - 1

    offset = 0
    previous_tail = b""

    while offset < size:
        to_read = min(chunk_size, size - offset)
        address = base + offset

        data = try_read_bytes(handle, address, to_read)
        if data is None:
            offset += to_read
            previous_tail = b""
            continue

        search_data = previous_tail + data

        start = 0
        while True:
            idx = search_data.find(signature, start)
            if idx == -1:
                break

            real_address = address - len(previous_tail) + idx
            matches.append(real_address)

            start = idx + 1

        previous_tail = search_data[-overlap:] if overlap > 0 else b""
        offset += to_read

    return matches