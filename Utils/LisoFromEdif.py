#!/usr/bin/env python

import sys, re
from pyparsing import *
from base64 import b64decode
from datetime import datetime
from StringIO import StringIO
from os import path
from itertools import product


### Define a parser for EDIF netlist files (uses the pyparsing module)

# based on edifToUcf.py by Andrew 'bunnie' Huang (copyright 2012, BSD license)

"""
BNF reference: http://theory.lcs.mit.edu/~rivest/sexp.txt

<sexp>    	:: <string> | <list>
<string>   	:: <display>? <simple-string> ;
<simple-string>	:: <raw> | <token> | <base-64> | <hexadecimal> | 
		           <quoted-string> ;
<display>  	:: "[" <simple-string> "]" ;
<raw>      	:: <decimal> ":" <bytes> ;
<decimal>  	:: <decimal-digit>+ ;
		-- decimal numbers should have no unnecessary leading zeros
<bytes> 	-- any string of bytes, of the indicated length
<token>    	:: <tokenchar>+ ;
<base-64>  	:: <decimal>? "|" ( <base-64-char> | <whitespace> )* "|" ;
<hexadecimal>   :: "#" ( <hex-digit> | <white-space> )* "#" ;
<quoted-string> :: <decimal>? <quoted-string-body>  
<quoted-string-body> :: "\"" <bytes> "\""
<list>     	:: "(" ( <sexp> | <whitespace> )* ")" ;
<whitespace> 	:: <whitespace-char>* ;
<token-char>  	:: <alpha> | <decimal-digit> | <simple-punc> ;
<alpha>       	:: <upper-case> | <lower-case> | <digit> ;
<lower-case>  	:: "a" | ... | "z" ;
<upper-case>  	:: "A" | ... | "Z" ;
<decimal-digit> :: "0" | ... | "9" ;
<hex-digit>     :: <decimal-digit> | "A" | ... | "F" | "a" | ... | "f" ;
<simple-punc> 	:: "-" | "." | "/" | "_" | ":" | "*" | "+" | "=" ;
<whitespace-char> :: " " | "\t" | "\r" | "\n" ;
<base-64-char> 	:: <alpha> | <decimal-digit> | "+" | "/" | "=" ;
<null>        	:: "" ;
"""

def verifyLen(s,l,t):
    t = t[0]
    if t.len is not None:
        t1len = len(t[1])
        if t1len != t.len:
            raise ParseFatalException(s,l,\
                    "invalid data of length %d, expected %s" % (t1len, t.len))
    return t[1]

# define punctuation literals
LPAR, RPAR, LBRK, RBRK, LBRC, RBRC, VBAR = map(Suppress, "()[]{}|")

decimal = Regex(r'0|[1-9]\d*').setParseAction(lambda t: int(t[0]))
hexadecimal = ("#" + OneOrMore(Word(hexnums)) + "#")\
                .setParseAction(lambda t: int("".join(t[1:-1]),16))
bytes_ = Word(printables)
raw = Group(decimal("len") + Suppress(":") + bytes_).setParseAction(verifyLen)
token = Word(alphanums + "-./_:*+=")
base64_ = Group(Optional(decimal|hexadecimal,default=None)("len") + VBAR 
    + OneOrMore(Word( alphanums +"+/=" )).setParseAction(lambda t: b64decode("".join(t)))
    + VBAR).setParseAction(verifyLen)
    
qString = Group(Optional(decimal,default=None)("len") + 
                        dblQuotedString.setParseAction(removeQuotes)).setParseAction(verifyLen)
smtpin = Regex(r'\&?\d+').setParseAction(lambda t: t[0])
#simpleString = base64_ | raw | decimal | token | hexadecimal | qString | smtpin 

# extended definitions
decimal = Regex(r'-?0|[1-9]\d*').setParseAction(lambda t: int(t[0]))
real = Regex(r"[+-]?\d+\.\d*([eE][+-]?\d+)?").setParseAction(lambda tokens: float(tokens[0]))
token = Word(alphanums + "-./_:*+=!<>")

#simpleString = real | base64_ | raw | smtpin | decimal | token | hexadecimal | qString
# get rid of real, base64_ processing passes to speed up parsing a bit
simpleString = raw | smtpin | decimal | token | hexadecimal | qString

display = LBRK + simpleString + RBRK
string_ = Optional(display) + simpleString

sexp = Forward()
sexpList = Group(LPAR + ZeroOrMore(sexp) + RPAR)
sexp << ( string_ | sexpList )


### Parse the netlist file

if len(sys.argv) != 2:
    print >>sys.stderr, "Usage:", sys.argv[0],
    print >>sys.stderr, "<edif filename>"
    raise SystemExit(1)

edifFile = file(sys.argv[1], 'rU')
netList = sexp.parseFile(edifFile, parseAll=True).asList()


### The following functions build a dict of parts using the parsed netlist

def stripCruft(netList):
    "Recursively remove some unused structures from the netlist."
    if isinstance(netList, list) and len(netList) > 0:
        # replace ['String', X] or ['InstanceRef', X] by X
        if netList[0] in ('String', 'InstanceRef'):
            return netList[1]
        # replace ['rename', X, Y] by Y
        elif netList[0] == 'rename':
            return netList[2]
        # replace ['Joined', X, ...] or ['PortRef', X, ...] by [X, ...]
        elif netList[0] in ('Joined', 'PortRef'):
            return [stripCruft(expr) for expr in netList[1:]]
        else:
            return [stripCruft(expr) for expr in netList]
    else:
        return netList


def extractParts(netList):
    "Recursively build a dict containing all the parts, indexed by their names."

    # Example part format:
    # (Instance partName
    #   (Property propName propValue)
    #   ...
    # )
    # Various other junk may also be present in an Instance list,
    # and is ignored.

    parts = {}
    for expr in netList:
        if isinstance(expr, list):
            if len(expr) > 0 and expr[0] == 'Instance':
                partName = expr[1]
                parts[partName] = {'Nets':{}}
                # the 'Nets' dict will be filled in later by connectParts()
                for item in expr[2:]:
                    if isinstance(item, list) and len(item) > 1 \
                        and item[0] == 'Property':
                        parts[partName][item[1]] = item[2]
            else:
                parts.update(extractParts(expr))
    return parts


def mangle(netName):
    "Shorten excessively long net names"
    if len(netName) < 15:
        return netName
    else:
        mangle = hash(netName) & 0xffffffff
        mangle = 'n' + str(mangle)
        return mangle


def connectParts(netList, parts):
    "Recursively add the net connections to the parts dict."

    # Example net format:
    # (Net netName
    #   (Joined
    #     (PortRef &pinNum (InstanceRef partName))
    #     ...
    #   )
    # )
    # Joined/PortRef/InstanceRef lists are pruned by stripCruft()
    # so the structure becomes:
    # (Net netName
    #   (
    #     (&pinNum partName)
    #     ...
    #   )
    # )

    for expr in netList:
        if isinstance(expr, list):
            if len(expr) > 0 and expr[0] == 'Net':
                netName = expr[1]
                netNodes = expr[2]
                for node in netNodes:
                    pinNum = int(node[0][1:])
                    partName = node[1]
                    parts[partName]['Nets'][pinNum] = mangle(netName)
            else:
                connectParts(expr, parts)


netList = stripCruft(netList)
parts = extractParts(netList)
connectParts(netList, parts)


### Assign a LISO command to each part

def fixVal(val):
    "Try to normalize component value to LISO format."
    # remove whitespace
    val = re.sub(r'\s*', '', val)
    # 1K -> 1k
    val = re.sub(r'([0-9.]+)K[FH]?', r'\1k', val)
    # 1k1 -> 1.1k
    val = re.sub(r'([0-9])([YZEPTGMkKhdcmunpfazy])([0-9])', r'\1.\3\2', val)
    # 1R -> 1
    val = re.sub(r'([0-9.]+)R', r'\1', val)
    # 1pF -> 1p, 1mH -> 1m
    val = re.sub(r'([0-9.]+[YZEPTGMkKhdcmunpfazy]?)F', r'\1', val)
    val = re.sub(r'([0-9.]+[YZEPTGMkKhdcmunpfazy]?)H', r'\1', val)
    return val

def addLisoCmd(parts):
    switchParts = []
    outputParts = []

    for partName in parts:
        part = parts[partName]
        origStdOut = sys.stdout
        sys.stdout = StringIO()

        if 'Value' in part:
            part['Value'] = fixVal(part['Value'])

        if 'VALUE' in part:
            part['Value'] = fixVal(part['VALUE'])

        try:
            # resistor: 'R partName value net1 net2'
            if 'Simulation' in part and part['Simulation'] == 'RESISTOR':
                print 'R', partName, part['Value'],
                print part['Nets'][1], part['Nets'][2]

            # capacitor: 'C partName value net1 net2'
            elif 'Simulation' in part and part['Simulation'] == 'CAP':
                print 'C', partName, part['Value'],
                print part['Nets'][1], part['Nets'][2]

            # inductor: 'L partName value net1 net2'
            elif 'Simulation' in part and part['Simulation'] == 'INDUCTOR':
                print 'L', partName, part['Value'],
                print part['Nets'][1], part['Nets'][2]

            # mutual inductance (transformer): 'M partName value partL1 partL2'
            # NOT YET IMPLEMENTED

            # op amp: 'OP partName type net+ net- netOutput'
            elif 'Part' in part and part['Part'] == 'Op Amp':
                print 'OP', partName, part['Comment'],
                print part['Nets'][3], part['Nets'][2], part['Nets'][6]

            # current input: IINPUT inputNet sourceImpedance
            # voltage input: UINPUT inputNet1 [inputNet2] sourceImpedance
            elif 'Description' in part and part['Description'] == \
                'Multicell Battery':
                print partName,
                if 1 in part['Nets']:
                    print part['Nets'][1],
                if 2 in part['Nets']:
                    print part['Nets'][2],
                if part['Comment']:
                    print part['Comment']
                else:
                    print

            # output parts need special handling: they must appear at the
            # end of the LISO file; and if more than one output is
            # present, multiple LISO files will be generated
            elif 'Description' in part and part['Description'] == 'Tie Point':
                outputParts.append(partName)

                # current output: IOUTPUT partName[coordinates]...
                if partName.upper().startswith('IOUTPUT'):
                    print 'IOUTPUT', part['Comment']

                # voltage output: UOUTPUT net[coordinates]...
                elif partName.upper().startswith('UOUTPUT'):
                    print 'UOUTPUT', part['Nets'][1] + part['Comment']

                # current noise: NOISE partName noiseSource...
                elif partName.upper().startswith('NOISE') and 1 not in part['Nets']:
                    print 'NOISE', part['Comment']
                    print 'NOISY ALL'

                # voltage noise: NOISE net noiseSource...
                elif partName.upper().startswith('NOISE'):
                    print 'NOISE', part['Nets'][1], part['Comment']
                    print 'NOISY ALL'

            # switch parts: these are also handled specially, and will
            # cause multiple LISO files to be generated
            elif 'Description' in part and part['Description'] == \
                'Single-Pole, Single-Throw Switch':
                switchParts.append(partName)

            else:
                raise Exception("Unknown Part: %s" % partName)

        except KeyError:
            print >>sys.stderr, 'Missing info about part', partName
            raise

        part['LisoCmd'] = sys.stdout.getvalue()
        sys.stdout.close()
        sys.stdout = origStdOut

    return outputParts, switchParts


outputParts, switchParts = addLisoCmd(parts)

constrainedSwitchParts = []
constraints = {}
for switchName in switchParts:
    part = parts[switchName]
    if 'Comment' in part and \
       part['Comment'].upper().startswith('CONSTRAINT'):
        constrainedSwitchParts.append(switchName)
        constraint = part['Comment'].split('=')[1].strip()
        if constraint not in constraints:
            constraints[constraint] = []
        constraints[constraint].append(switchName)


### Output LISO files

origStdOut = sys.stdout
sys.stdout = StringIO()

print '# Autogenerated on', datetime.now().strftime('%Y-%m-%d %H:%M'),
print 'by', ' '.join(sys.argv)

print 'FREQ LOG 0.1 100k 300'

for partName in parts:
    if partName in outputParts or partName in switchParts:
        continue
    sys.stdout.write(parts[partName]['LisoCmd'])

normalPartCmds = sys.stdout.getvalue()
sys.stdout.close()
sys.stdout = origStdOut


edifFileRoot, edifFileExt = path.splitext(sys.argv[1])
edifFilePath, edifFileBase = path.split(edifFileRoot)

if len(switchParts) > 0:
    lisoStates = [[(switchName,0), (switchName,1)]
                  for switchName in switchParts
                  if switchName not in constrainedSwitchParts]
    if len(outputParts) > 0:
        lisoStates.append(outputParts)
    lisoStates = product(*lisoStates)
else:
    lisoStates = product(outputParts)

lisoStates = [x for x in lisoStates]

if len(lisoStates) <= 1:
    # special case: make only one LISO file
    lisoFileName = edifFileBase + '.fil'
    sys.stdout = file(lisoFileName, 'w')
    sys.stdout.write(normalPartCmds)
    for outputName in outputParts:
        sys.stdout.write(parts[outputName]['LisoCmd'])
else:
    # general case: multiple files needed
    for lisoState in lisoStates:
        # generate the file name for this state
        lisoFileName = edifFileBase
        for item in lisoState:
            if isinstance(item, tuple):
                # this item is a switch
                switchName = item[0]
                switchOn = item[1]
                lisoFileName += '_' + switchName + '-' + str(switchOn)
            else:
                # this item is an output
                outputName = item
                lisoFileName += '_' + outputName
        lisoFileName += '.fil'
        sys.stdout = file(lisoFileName, 'w')

        # write the LISO commands
        sys.stdout.write(normalPartCmds)

        for item in lisoState:
            if isinstance(item, tuple):
                # this item is a switch
                switchName = item[0]
                switchOn = item[1]
                print 'R', switchName,
                if switchOn:
                    print '0',
                else:
                    print '999M',
                print parts[switchName]['Nets'][1],
                print parts[switchName]['Nets'][2]
                # check for other switches constrained to follow this one
                if switchName in constraints:
                    for otherSwitchName in constraints[switchName]:
                        print 'R', otherSwitchName,
                        if switchOn:
                            print '0',
                        else:
                            print '999M',
                        print parts[otherSwitchName]['Nets'][1],
                        print parts[otherSwitchName]['Nets'][2]
            else:
                # this item is an output
                outputName = item
                sys.stdout.write(parts[outputName]['LisoCmd'])


