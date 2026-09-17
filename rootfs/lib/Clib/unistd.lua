local unistd = {}

local function syscall(id, ...)
    return coroutine.yield({0x01, id, ...})
end

function unistd.read(fd, size)
    return syscall(0x00, fd, size)
end

function unistd.write(fd, data)
    return syscall(0x01, fd, data)
end

function unistd.close(fd)
    return syscall(0x03, fd)
end

function unistd.pipe()
    return syscall(0x16)
end

function unistd.getpid()
    return syscall(0x27)
end

function unistd.execve(path, options, ...)
    return syscall(0x3B, path, options, ...)
end

function unistd.getcwd()
    return syscall(0x4F)
end

function unistd.chdir(path)
    return syscall(0x50, path)
end

function unistd.rmdir(path)
    return syscall(0x54, path)
end

function unistd.unlink(path)
    return syscall(0x57, path)
end

function unistd.getuid()
    return syscall(0x66)
end

function unistd.setuid(target_uid)
    return syscall(0x69, target_uid)
end

function unistd.stat(path)
    return syscall(0x04, path)
end

function unistd.wait(pid)
    return syscall(0x3D, pid)
end

function unistd.readdir(path)
    return syscall(0xD9, path)
end

function unistd.assign_tty(pid, tty_id)
    return syscall(0x201, pid, tty_id)
end

function unistd.clock_gettime(clock_type)
    return syscall(0xE4, clock_type)
end

function unistd.error(msg)
    return syscall(0x01, 2, msg)
end

function unistd.mkdir(path)
    return syscall(0x53, path)
end

function unistd.getdents64(path)
    return syscall(0xD9, path)
end

function unistd.exit(exit_code)
    return syscall(0x3C, exit_code)
end

function unistd.rename(src, final_path)
    return syscall(0x52, src, final_path)
end

function unistd.dup(oldfd)
    return syscall(0x20, oldfd)
end

function unistd.dup2(oldfd, newfd)
    return syscall(0x21, oldfd, newfd)
end

function unistd.http_get(url)
    return syscall(0x40, url)
end

function unistd.http_resolve(response)
    return syscall(0x41, response)
end

function unistd.kill(pid)
    return syscall(0x3E, pid)
end

function unistd.sleep(seconds)
    return coroutine.yield({0x03, seconds})
end

return unistd