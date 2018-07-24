/*
  
  Referenced Code: 
    http://konstructcomputers.blogspot.com/2013/12/groovy-line-by-line-process-output.html
*/

package org.estf.gradle

import org.apache.tools.ant.util.LineOrientedOutputStream

class ShellCommand
{
  private final String cmd
  private final boolean echo
  private final Process proc
  private final Thread outThread
  private final Thread errThread
  private final List outLines = []
  private final List errLines = []

  private class LineOutput extends LineOrientedOutputStream
  {
    boolean echo
    String prefix
    List lines

    @Override
    protected void processLine(String line) throws IOException
    {
      lines.add(line)
      if (echo)
        //println "${new Date().format('yyyy-MM-dd HH:mm:ss.SSS')} ${prefix} : ${line}"
        println "${line}"
    }
  }


  ShellCommand(String cmd, String workingDir = null, List envVars = null)
  {
    this.cmd = cmd
    this.echo = true
    if (! workingDir?.trim()) {
     workingDir = System.getProperty("user.dir")
    }
    this.proc = cmd.execute(envVars, new File(workingDir))
    // Start the stdout, stderr spooler threads
    outThread = proc.consumeProcessOutputStream(new LineOutput(echo: echo, prefix: "", lines: outLines))
    errThread = proc.consumeProcessErrorStream(new LineOutput(echo: echo, prefix: "", lines: errLines))  
  }

  def waitFor() 
  {
    proc.waitFor()
    _done()
  }

  def waitForOrKill(int millis)
  {
    proc.waitForOrKill(millis)
    _done()
  }

  private void _done()
  {
    try { outThread.join(); } catch (InterruptedException ignore) {}
    try { errThread.join(); } catch (InterruptedException ignore) {}
    try { proc.waitFor(); } catch (InterruptedException ignore) {}
    proc.closeStreams()
  }

  def getRc()
  {
    def rc = null
    try { rc = proc.exitValue() } catch (IllegalThreadStateException e) {}
    return rc
  }
}