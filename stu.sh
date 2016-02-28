#!/bin/sh

python -c "
try : 
	x=u'$1' 
	x.decode('ascii')
except UnicodeEncodeError:
	print 'weird' 
else : 
	print 'normal' 
"
