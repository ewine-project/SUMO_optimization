%KILL Send a signal to a process.
%   KILL(PID,SIGNAL) allows Matlab to signal the process PID with the signal
%   SIGNAL without the overhead of using the SYSTEM command.  The other process
%   need not be another Matlab session.  This program signals processes via the
%   signal.h mechanism.  Both PID and SIGNAL must be scalar integers.
%   
%   For more information, type
%       system('man kill')
%   and/or
%       system('man signal.h')
%
%   See also SYSTEM.
%
%   Copyright (c) 2011, Joshua V Dillon
%   All rights reserved. (Type "help dillon_license" for details.)

%   Copyright 2011 Joshua V Dillon
%   $Revision: 0.9.0.0 $  $Date: 2011/01/20 13:38 $

%   Built-in function.

