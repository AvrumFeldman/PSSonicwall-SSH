function New-SshSession {
    param([parameter(Mandatory)]$server)
    $global:session = [Renci.SshNet.SshClient]::new($server,"admin",'')
    $session
}

function Test-SshSession {
    if (!(Test-Path variable:\session)) {
        throw "No session exsists. Please create one first by using New-SSHSession"   
    }
    if (!($session.isconnected)) {
        throw "Not connected to the device. Run Connect-SSHSession to connect and create a new shell."
    }
}

function Connect-SSHSession {
    param($f_session = $session)
    if (!($session.IsConnected)) {
        $f_session.connect()
    }
    $global:shell = $f_session.CreateShellStream("dumb", 0, 0, 0, 0, 3000)
    start-sleep -Seconds 3
    if ($shell.read() -match "Password:") {
        $shell.Writeline("O5GG9dIq")
        $shell.WriteLine("no cli pager session")
        $shell.WriteLine("cli output-format plain-text")
    }
    $shell
}

function Test-SshShell {
    Test-SshSession
    [void]$shell.read()
    $shell.WriteLine('')
    start-sleep -Seconds 3
    $response = $shell.read()
    $response -match ">|config"
}

function Invoke-SshCommand {
    param($shell = $shell, $command)
    $shell.read()
    $shell.WriteLine("$command")
    start-sleep -Seconds 1
    $shell.read()
}

function Test-SshConfigMode {
    param($shell = $shell)
    Test-SshShell | out-null
    [void]$shell.read()
    $shell.writeline("")
    Start-Sleep -Milliseconds 500
    $read = $shell.read()
    $shell.WriteLine('')
    $read -match 'config\('
}

function Enter-SshConfigmode {
    param($shell = $shell)
    Test-SshShell | out-null
    [void]$shell.read()
    if (!(Test-SshConfigMode)) {
        $shell.writeline("configure")
        start-sleep -Seconds 1
        $output = $shell.read()
        if ($output -match "Do you wish") {
            $shell.writeline("yes")
        }
    } 
    Test-SshConfigMode
}