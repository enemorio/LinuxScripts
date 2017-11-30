from __future__ import print_function
import os

os.getcwd()

a = []
b = []
c = ''
d = {}

def format_string(s):
  s = s.replace('\\\\','\\')
  s = s.replace('/', '\\')
  return s

os.system('drivers >a drivers.txt')
with open('drivers.txt', 'r') as f:
  for line in f:
    a.append(line)

for entry in a:
  if entry.find('Apache Pass') > 0:
    b.append(entry[0:3])

os.system('rm drivers.txt -q')
print('Apache Driver BIOS handles: ', end='')
print(b)

print('Searching for Apache Drivers in disk. Please wait...')
counter = 0
for root, dirs, files in os.walk('/'):
  for file in files:
    if file.find('ApachePassDriver.efi') > -1:
      counter += 1
      d.update({counter : (format_string(root), format_string(file)) })
    elif file.find('ApachePassHii.efi') > -1:
      counter += 1
      d.update({counter : (format_string(root), format_string(file)) })
if counter == 0:
    print('ERROR: No ApachePass Drivers Found in disk.')
else:
    os.system('unload ' + b[0] + ' -n')
    os.system('unload ' + b[1] + ' -n')

for i in d:
  print(i, end=': ')
  print(d[i][0] + '\\' + d[i][1])

print('Please input first driver to load', end=': ')
e = raw_input()
e = int(e)

os.system('load  ' + d[e][0] + '\\' + d[e][1] )
os.system('load  ' + d[e+1][0] + '\\' + d[e+1][1] )

os.system('cd ' + d[e][0])