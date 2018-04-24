# MinecraftStartupScript
Custom startup script, used on the ZephyrUnleashed server. Forked by speeddemon574 to add the ability to 
have the server automatically restart should it crash.


To use the automatic restart feature add this line to the crontab of whatever user is being used to run the server by using the command: `crontab -e`.

`*/1 * * * * /home/YOURUSERNAME/MINECRAFTSERVERDIR/start.sh start >/dev/null 2>&1`





You can also do automatic world saves every 5 minutes by adding this to the crontab (I did not add this functionality in this fork).

`*/5 * * * * /home/minecraft/mainMC/start.sh save >/dev/null 2>&1`
