from __future__ import division
import argparse

lang = { 'german':   { 'e': 16.93, 'n': 10.53, 'i': 8.02, 'r': 6.89, 's': 6.42 },
         'english':  { 'e': 12.60, 't': 9.37, 'a': 8.34, 'o': 7.70, 'n': 6.80 },
         'franz':    { 'e': 15.10, 'a': 8.13, 's': 7.91, 't': 7.11, 'i': 6.94 }}
res = {}

parser = argparse.ArgumentParser(description='Print the letter frequency of a text.')
parser.add_argument('-f', '--file', help='a file with text to analyse')

args = parser.parse_args()

f = open(args.file)

letter_freq = {k: 0 for k in map(chr, range(97,123))}

letter_total = 0
for i in f.read():
    if ord(i.lower()) >= 97 and ord(i.lower()) <= 122:
        letter_total += 1
        letter_freq[i.lower()] += 1

for i in letter_freq:
    letter_freq[i] = round((letter_freq[i]/letter_total) * 100, 2)
 
print sorted(letter_freq, key=letter_freq.__getitem__, reverse=True)
f.close()
