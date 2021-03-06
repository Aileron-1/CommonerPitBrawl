/// Read incoming data to the server from a connected socket
{  
    // get the buffer the data resides in
    buff = ds_map_find_value(async_load, "buffer");
    
    // read ythe command 
    cmd = buffer_read(buff, buffer_s16 );

    // Get the socket ID - this is the CLIENT socket ID. We can use this as a "key" for this client
    sock = ds_map_find_value(async_load, "id");
    // Look up the client details
    inst = ds_map_find_value(Clients, sock);

    var out = 0; // returned value
    
    // Is this a KEY command?
    if (cmd == KEY_CMD) {
        // Read the key that was sent
        var key = buffer_read(buff, buffer_s16 );
        // And it's up/down state
        var updown = buffer_read(buff, buffer_s16 );
    
        // translate keypress into an index for our player array.
        if( key == vk_left ) {
            key=LEFT_KEY;
        }
        else if( key == vk_right ) {
            key=RIGHT_KEY;
        }
         
        // translate updown into a bool for the player array       
        if( updown == 0 ){
            inst.keys[key] = false;
        }else{
            inst.keys[key] = true;
        }
    }
    // Is this a NAME command?
    else if( cmd == NAME_CMD ) {
        buffer_read(buff, buffer_s16);  // data size
        
        inst.name = buffer_read(buff, buffer_string);  // name
        inst.race = buffer_read(buff, buffer_string);  // race
        inst.subrace = buffer_read(buff, buffer_string);  // subrace
        inst.class = buffer_read(buff, buffer_string);  // class
        inst.level = buffer_read(buff, buffer_s16);  // level
        inst.age = buffer_read(buff, buffer_s16);  // age
        
        inst.str = buffer_read(buff, buffer_s16);  // str
        inst.dex = buffer_read(buff, buffer_s16);  // dex
        inst.con = buffer_read(buff, buffer_s16);  // con
        inst.int = buffer_read(buff, buffer_s16);  // int
        inst.wis = buffer_read(buff, buffer_s16);  // wis
        inst.cha = buffer_read(buff, buffer_s16);  // cha
        
        inst.sprite_index = buffer_read(buff, buffer_s16);  // sprite index
        inst.image_index = buffer_read(buff, buffer_s16);  // image index
        
        with (inst) {CalcStats();}  // Update stats
        inst.hp = inst.maxHp;
        
        inst.loaded = 1;  // Show player, now that it's updated
        
        // Notify clients of new player
        SendLog(inst.name+' has joined.');
        SendLog('Stats: '+string(inst.str)+' '+string(inst.dex)+' '+string(inst.con)+' '+string(inst.int)+' '+string(inst.wis) +' '+string(inst.cha));
        
    }
    else if( cmd == PING_CMD ) {
        // keep alive - ignore it
    }
    else if( cmd == MOVE_CMD ) {
        var go_xx = buffer_read(buff, buffer_s16 );
        var go_yy = buffer_read(buff, buffer_s16 );
        var go_moveType = buffer_read(buff, buffer_s16 );  // Why is the client deciding the move type???
        
        var go_dist = abs(go_xx-inst.xx)+abs(go_yy-inst.yy);  // Distance to travel
        
        // Check if inst has enough movement
        if (inst.movement/BLOCK_FT >= go_dist) {
            inst.xx = go_xx;
            inst.yy = go_yy;
            inst.movement -= go_dist*BLOCK_FT;
            inst.moveType = go_moveType;
        }
    }
    else if( cmd == TURN_CMD ) {
        // Validate turn (if the turn ender is the turn holder)
        if (inst.turn == 1) {
            // take away turns from everyone
            var h = ds_list_size(entities)-1;//ds_grid_height(entitiesInitiatives);
            if (initiativeIndex < h) initiativeIndex += 1;
            else initiativeIndex = 0;
            // give turn
            var instNext = entities[| initiativeIndex];//ds_grid_get(entitiesInitiatives, 0, initiativeIndex);
            GiveEntityTurn(socketlist,Clients,instNext);
            SendLog('('+inst.name+ "'s turn.)")
        }
    }
    else if( cmd == ACTION_CMD ) {
        actionType = buffer_read(buff, buffer_string);
        switch (actionType) {
            case 'Dash':
                if (inst.action[0] > 0) {
                    inst.movement += inst.maxMovement;
                    inst.action[0] -= 1;
                    SendLog(inst.name+ ' dashes.');
                }
                break;
            case 'Attack':
                if (inst.action[0] > 0) {
                    var hit = RollDice(1,20) + inst.str_mod + inst.prof_mod;   
                    var dmg = max(1,1+inst.str_mod);
                    SendLog(inst.name+ ' attacks: '+ string(hit));
                    ServerAttack(hit, dmg);
                    inst.action[0] -= 1;
                }
                break;
            case 'Bonus attack':
                if (inst.action[1] > 0) {
                    var hit = RollDice(1,20) + inst.str_mod + inst.prof_mod;
                    var dmg = 1;
                    SendLog(inst.name+ ' uses bonus attack: '+ string(hit));
                    ServerAttack(hit, dmg);
                    inst.action[1] -= 1;
                }
                break;
        }
    }
    return cmd;
}


