Rem Script by SRIVENU KADIYALA - mail - srivenu@hotmail.com

col SERVICE_ID head "ID" form 999
col NAME head "Service Name" form a35
col CON_NAME head "Container" form a10
col NETWORK_NAME head "Network Name|used to connect" form a35
col GOAL head "Runtime|Load|Balancing|Goal" form a10
col CLB_GOAL head "Connection|Load|Balancing|Goal" form a10
col BLOCKED head "Blocked|on this|Instance" form a10
col STOP_OPTION head "Stop Option|for Sessions" form a10

select	SERVICE_ID, NAME, CON_NAME, NETWORK_NAME, GOAL, CLB_GOAL, BLOCKED
from	V$ACTIVE_SERVICES
order	by 2
/
