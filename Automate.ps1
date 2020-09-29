function Test-SshSession {
    [cmdletbinding()]
    param($loop_level = 0)
    write-debug "$($MyInvocation.MyCommand)[$($loop_level)]"
    if ($loop_level -gt 1) {
        throw "$($MyInvocation.MyCommand)[$($loop_level)]: Something is worng here. We are already at loop level $($loop_level)."
    }
    write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Testing for session variable"
    if (!(Test-Path variable:\session)) {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: No SSH session found. Creating a new one. Loop level: $($loop_level)"
        New-SshSession
        Test-SshSession -loop_level ($loop_level + 1)
    } else {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Session variable exists."
    }
    write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Testing if session is closed."
    if (!($session.isconnected)) {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: SSH session is not connected"
        return $false
        # throw "Not connected to the device. Run Connect-SSHSession to connect and create a new shell."
    }
    write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: session is open"
    return $true
}

function Test-SshShell {
    [cmdletbinding()]
    param()
    write-debug "$($MyInvocation.MyCommand)"
    if (Test-SshSession) {
        try {
            [void]$shell.read()
            $shell.WriteLine('')
            write-verbose "$($MyInvocation.MyCommand): Sleeping for 1 seconds to give time for the shell to respond"
            start-sleep -Seconds 1
            $response = $shell.read()
            $response -match ">|config"
            write-verbose "$($MyInvocation.MyCommand): We have shell? $($response -match ">|config")."
        } catch {
            write-verbose "$($MyInvocation.MyCommand): We don't have yet a shell"
            return $false
        }

    } else {
        write-verbose "$($MyInvocation.MyCommand): The SSH session is either not connected."
        write-verbose "$($MyInvocation.MyCommand): Run connect-sshsession to connect."
        return $false
    }
}

function Test-SshConfigMode {
    [cmdletbinding()]
    param($shell = $global:shell,$loop_level = 0)
    write-debug "$($MyInvocation.MyCommand)[$($loop_level)]"
    if ($loop_level -gt 1) {
        throw "$($MyInvocation.MyCommand)[$($loop_level)]: Something is worng here. We are already at loop level $($loop_level)."
    }
    if (Test-SshShell) {
        [void]$shell.read()
        $shell.writeline("")
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Sleeping for 500 milliseconds to give the shell time to respond"
        Start-Sleep -Milliseconds 500
        $read = $shell.read()
        return ($read -match 'config\(')
    } else {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: We are not even connected to any session."

        #As we are testing config mode, we assume that the user wants to be connected to a session and we aren't connected. So we will take error correction action and connect to the session.
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: calling Connect-SSHSession"
        Connect-SSHSession
        # return $false
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Now that we hopfully are connected to a session, we still need to find out if we have config mode or not."
        Test-SshConfigMode -loop_level ($loop_level + 1)
    }
}

function New-SshSession {
    param([parameter(Mandatory)]$server)
    write-debug "$($MyInvocation.MyCommand)"
    remove-item env:\swlegacy -ErrorAction:SilentlyContinue
    if ($server) {
        $global:session = [Renci.SshNet.SshClient]::new($server,"admin",$plaintext_password)
        $session.ConnectionInfo.Timeout = [timespan]::FromSeconds(5)
        $session.ConnectionInfo.RetryAttempts = 5
    }
    # $session
}

function Connect-SSHSession {
    [cmdletbinding()]
    param($session = $session, $lagecy = $env:swlegacy,$loop_level = 0)
    write-debug "$($MyInvocation.MyCommand)[$($loop_level)]"
    if ($loop_level -gt 1) {
        throw "$($MyInvocation.MyCommand)[$($loop_level)]: Something is worng here. We are already at loop level $($loop_level)."
    }
    if (Test-SshSession) {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)] We were still connected to the session. reconnecting..."
        $session.disconnect()
    }
    try {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: attempting to connect to $($session.ConnectionInfo.Host)"
        $session.connect()
    } catch {
        Throw "Unable to connect to device."
    }
    $connectd = Test-SshSession
    Write-Verbose "$($MyInvocation.MyCommand)[$($loop_level)]: $connectd"
    if ($connectd) {
        $global:shell = $session.CreateShellStream("dumb", 0, 0, 0, 0, 3000)
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Sleeping for 2 seconds to give time for the shell to respond"
        start-sleep -Seconds 2
        if ($global:shell.read() -notmatch "admin@.*>") {
            $global:shell.Writeline($plaintext_password)
            $global:shell.WriteLine("no cli pager session")
            $global:shell.WriteLine("cli output-format plain-text")
            $env:swlegacy = $true
        } else {
            $global:shell.WriteLine("no cli pager session")
            $global:shell.WriteLine("cli format out plain-text")
            $env:swlegacy = $false
        }
        $global:shell
    } else {
        Write-Verbose "$($MyInvocation.MyCommand)[$($loop_level)]: We are still not connected. Attempting again."
        Connect-SSHSession -loop_level ($loop_level + 1)
    }
}

function Enter-SshConfigmode {
    [cmdletbinding()]
    param($shell = $global:shell, $loop_level = 0)
    write-debug "$($MyInvocation.MyCommand)[$($loop_level)]"
    if ($loop_level -gt 1) {
        throw "$($MyInvocation.MyCommand)[$($loop_level)]: Something is worng here. We are already at loop level $($loop_level)."
    }
    if (!(Test-SshConfigMode)) {
        $shell.writeline("configure")
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Sleeping for 1 second to give the shell time to respond"
        start-sleep -Seconds 1
        $output = $shell.read()
        if ($output -match "Do you wish") {
            write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: preempted. Kicking out other admin"
            $shell.writeline("yes")
        }
    }
    write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: confirming we are indead in config mode. Loop level: $($loop_level)"
    if (!(Test-SshConfigMode)) {
        write-verbose "$($MyInvocation.MyCommand)[$($loop_level)]: Nope, not yet in config mode. Attempting again."
        Enter-SshConfigmode -loop_level ($loop_level + 1)
    } else {
        $true
    }
} 