function New-SshSession {
    param([parameter(Mandatory)]$server)
    remove-item env:\swlegacy -ErrorAction:SilentlyContinue
    $global:session = [Renci.SshNet.SshClient]::new($server,"admin",'')
    $session
}

function Test-SshSession {
    [cmdletbinding()]
    param()
    write-verbose "$($MyInvocation.MyCommand): Testing for session variable"
    if (!(Test-Path variable:\session)) {
        throw "No session exsists. Please create one first by using New-SSHSession"   
    }
    write-verbose "$($MyInvocation.MyCommand): Testing is session is closed."
    if (!($session.isconnected)) {
        throw "Not connected to the device. Run Connect-SSHSession to connect and create a new shell."
    }
}

function Connect-SSHSession {
    [cmdletbinding()]
    param($ession = $session, $lagecy = $env:swlegacy)
    if ($session.IsConnected) {
        throw "We are still connected to the session"
    }
    $session.connect()
    $global:shell = $session.CreateShellStream("dumb", 0, 0, 0, 0, 3000)
    Write-verbose "$($MyInvocation.MyCommand): Sleeping for 2 seconds to give time for the shell to respond"
    start-sleep -Seconds 2
    if ($shell.read() -notmatch "admin@.*>") {
        $env:swlegacy = $true
        $shell.Writeline("O5GG9dIq")
        $shell.WriteLine("no cli pager session")
        $shell.WriteLine("cli output-format plain-text")
    } else {
        $shell.WriteLine("no cli pager session")
        $shell.WriteLine("cli format out plain-text")
        $env:swlegacy = $false
    }
    $shell
}

function Test-SshShell {
    [cmdletbinding()]
    param()
    Test-SshSession
    [void]$shell.read()
    $shell.WriteLine('')
    write-verbose "$($MyInvocation.MyCommand): Sleeping for 1 seconds to give time for the shell to respond"
    start-sleep -Seconds 1
    $response = $shell.read()
    $response -match ">|config"
}

function Invoke-SshCommand {
    [cmdletbinding()]
    param($shell = $shell, $command)
    $shell.read()
    $shell.WriteLine("$command")
    write-verbose "$($MyInvocation.MyCommand): Sleeping for 1 seconds to give time for the shell to respond"
    start-sleep -Seconds 1
    $shell.read()
}

function Test-SshConfigMode {
    [cmdletbinding()]
    param($shell = $shell)
    if (Test-SshShell) {
        [void]$shell.read()
        $shell.writeline("")
        write-verbose "$($MyInvocation.MyCommand): Sleeping for 500 milliseconds to give the shell time to respond"
        Start-Sleep -Milliseconds 500
        $read = $shell.read()
        $read -match 'config\('
    }
}

function Enter-SshConfigmode {
    [cmdletbinding()]
    param($shell = $shell)
    if (!(Test-SshConfigMode)) {
        $shell.writeline("configure")
        write-verbose "$($MyInvocation.MyCommand): Sleeping for 1 second to give the shell time to respond"
        start-sleep -Seconds 1
        $output = $shell.read()
        if ($output -match "Do you wish") {
            write-verbose "$($MyInvocation.MyCommand): preempted. Kicking out other admin"
            $shell.writeline("yes")
        }
    }
    write-verbose "$($MyInvocation.MyCommand): confirming we are indead in config mode"
    Test-SshConfigMode
}
