#!/usr/bin/env python
from random import choice

COL_NORMAL  = '\033[0m'
COL_RED     = '\033[1;31m'
COL_GREEN   = '\033[1;32m'
COL_YELLOW  = '\033[1;33m'
COL_BLUE    = '\033[1;34m'
COL_WHITE   = '\033[1;37m'
COL_CYAN    = '\033[1;36m'
COL_GREY    = '\033[1;30m'
cols = [COL_RED, COL_GREEN, COL_YELLOW, COL_BLUE, COL_WHITE, COL_CYAN]

def color():
    c = cols.pop()
    cols.insert(0, c)
    return c

def isbit(ch):
    return (ch in ['1', '0'])

BIT_SEPARATOR = '  '

class bits():
    '''
    Class, which represents an int value in a bit string.
    '''
    def __init__(self, n, nbits=8, descr=''):
        self.bit = (n, nbits)
        self.descr = descr

    def nbits(self):
        return self.bit[1]

    def val(self):
        return self.bit[0]

    def sign(self):
        '''
        returns value description
        '''
        return self.sign

    def ruler(self):
        '''
        returns a ruler for bit string representation
        '''
        return '|' + ''.join(['-' for i in range((self.nbits() - 1) * len(BIT_SEPARATOR) + self.nbits())]) + '|'

    def __str__(self):
        '''
        returns bit string representation, each bit is separated by BIT_SEPARATOR,
        string is prefixed and suffixed by one space.
        '''
        return ' ' + BIT_SEPARATOR.join([str((self.val() >> n) & 1) for n in range(self.nbits())][::-1]) + ' '

    def __repr__(self):
        return str(self.bit)

class bitfield():
    BIT_OFFSET_MARK  = 4     # mark offset every OFFSET_MARK bits
    MAX_OFFSET_LEN   = 2     # max number of digits in offset

    ints = []           # Bitfields list, must be bit() instance
    width = 16          # Bits per string
    endianness = 'l'    # only little endian for now, TODO: add support for more

    def __init__(self, *args, **kwargs):
        self.ints = list()

        for arg in list(args):
            if arg.__class__ == int:
                self.ints.append(bits(arg))

            elif arg.__class__ == tuple and len(arg) == 2:
                self.ints.append(bits(arg[0], arg[1]))

            elif arg.__class__ == bits:
                self.ints.append(arg)

        if kwargs.get('reverse', None) != None:
            self.reverse()

        if kwargs.get('width', None) != None:
            self.width = kwargs.get('width', 16)

    def reverse(self):
        self.ints = self.ints[::-1]

    def bitstr(self):
        res = '\n'

        # create bit offset marks for every BIT_OFFSET_MARK bits
        bit_offset_marks = []
        # for every bit string
        for n in range(self.nbits_total(), 0, -self.width): # little endian order
            marks = ' '
            # for every mark
            for i in range(0, self.width, self.BIT_OFFSET_MARK):
                # add offsets
                for sp in range(0, len(BIT_SEPARATOR) * (self.BIT_OFFSET_MARK - 1) + self.BIT_OFFSET_MARK):
                    marks += ' '

                nmark = n - i - self.BIT_OFFSET_MARK
                if nmark < 0: break
                mark = str(nmark)
                while len(mark) < self.MAX_OFFSET_LEN: mark = '0' + mark
                marks += mark

            bit_offset_marks.append(marks)

        # pass one: concatenate components
        s = ''.join([str(i) for i in self.ints])

        # pass two: leave only `width` bits on one line,
        #           add space for offset marks
        npbits = 0
        ns = ''
        cbitcnt = 0
        intidx = 0
        ccol = color()
        for ch in s:
            if isbit(ch):
                if cbitcnt >= (self.ints[intidx].nbits() - 1):
                    cbitcnt = 0
                    intidx += 1
                    ccol = color()
                else:
                    ns += ccol
                    cbitcnt += 1

                if npbits and (npbits % self.width) == 0:
                    ns += '\n ' + ccol
                npbits += 1
                ns += ch
            else:
                ns += ch

        bitlist = ns.splitlines()

        for i in range(len(bitlist)):
            res += COL_GREY + bit_offset_marks[i] + '\n'
            res += bitlist[i] + '\n'

        return res

    def __repr__(self):
        return self.bitstr()

    def __str__(self):
        return self.bitstr()

    def nbits_total(self):
        n = 0
        for i in self.ints: n += i.nbits()
        return n

    @classmethod
    def byte(cls, bit):
        return bit / 8
