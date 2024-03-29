"use strict";

// Save a reference to the original. We'll be redefining it.
var parentDisconnected = connDisconnected;

//-----Component Setup
    var bigMapHREF;
    var jitsiDomain, jitsiNickname, jitsiServerMuted, jitsiRoom, jitsiToken, jitsiClientMuted, jitsiScriptLoaded, jitsiAPI, jitsiSilenced;
    var jitsiMidMute, jitsiAddedAudioInputListener, jitsiLastAudioDevice, jitsiChannels, jitsiCalledInit;
    function initTheatre() {
        addComponent('chat_theatre'   , 'left'    , false, 'openerWin', ['http://game.gables.chattheatre.com/'], '<img alt="Grand Theatre" src="http://images.gables.chattheatre.com/gamelogo.jpg">');
        addComponent('skotos_logo'    , 'right'   , false);
        addComponent('clientui'       , 'skotos_logo');
        addComponent('save_button'    , 'clientui', false, 'saveCurrentWindow', [], '<i class="fas fa-file-download"></i>', 'Save Log');
        addComponent('settings_button', 'clientui', false, 'openSettings', [], '<i class="fas fa-bars"></i>', 'Client Preferences');
        addComponent('newplayersgs'   , 'right'   , false, 'openerWin', ['http://game.gables.chattheatre.com/Theatre/starting.sam'], '<div class="button" alt="Getting Started" title="Getting Started">Getting Started</div>');
        addComponent('newplayersmc'   , 'right'   , false, 'openerWin', ['http://game.gables.chattheatre.com/Theatre/mastering.sam'], '<div class="button" alt="Mastering Chat" title="Mastering Chat">Mastering Chat</div>');
        addComponent('audio_settings' , 'right'   , false);
        addComponent('audio_silence'  , 'audio_settings', false, 'toggleSilenced', [], '<div class="button"><i id="silence_button" title="speaker shows whether you are playing audio chat" class="silenced fas fa-volume-mute"></i><span id="silence_indicator">Audio Chat</span></div>')
        addComponent('audio_mute'     , 'audio_settings', false, 'toggleClientMuted', [], '<div class="button"><i id="mute_button" title="microphone shows whether you have muted yourself" class="muted fas fa-microphone-alt-slash"></i><span id="chat_indicator" title="text color shows whether server has muted you...">Mute/Unmute</span></div>');
        addComponent('audio_roomtext' , 'audio_settings', false, false, [], '<div class="button">Room: <span id="audio_room"></span</div>');
        //addComponent('audio_device'     , 'right'   , 'audio_device', false, [], '<select id="audio_input_devices"></div>');
        addComponent('right_fill'     , 'right'   , 'fill');
        addComponent('image_map'      , 'right'   , false, 'popupMapWindow', []);
        addComponent('image_map_img'  , 'image_map', false);
        addComponent('comp_nw', 'right_fill', 'comp_button', 'compassArrow', ['northwest'], false, 'go northwest');
        addComponent('comp_n' , 'right_fill', 'comp_button', 'compassArrow', ['north'],     false, 'go north');
        addComponent('comp_ne', 'right_fill', 'comp_button', 'compassArrow', ['northeast'], false, 'go northeast');
        addComponent('comp_w' , 'right_fill', 'comp_button', 'compassArrow', ['west'],      false, 'go west');
        addComponent('comp_e' , 'right_fill', 'comp_button', 'compassArrow', ['east'],      false, 'go east');
        addComponent('comp_sw', 'right_fill', 'comp_button', 'compassArrow', ['southwest'], false, 'go southwest');
        addComponent('comp_s' , 'right_fill', 'comp_button', 'compassArrow', ['south'],     false, 'go south');
        addComponent('comp_se', 'right_fill', 'comp_button', 'compassArrow', ['southeast'], false, 'go southeast');
    }

    function initJitsi() {
        jitsiCalledInit = true;
        jitsiScriptLoaded = false;
        jitsiMidMute = false;
        jitsiAddedAudioInputListener = false;
        jitsiServerMuted = false;
        jitsiClientMuted = true;
        jitsiSilenced = false;

        if(window.location.hostname != "localhost" && !jitsiDomain) {
            jitsiDomain = window.location.hostname.replace("rwot.", "meet.");
        }

        // Show the current silenced and muted settings in the sidebar
        updateSilencedUI();
        updateMutedUI();

        // Add the Jitsi external_api script for our correct domain
        var script = document.createElement('script');
        script.type = 'text/javascript';
        script.src = 'https://' + jitsiDomain + '/external_api.js';
        document.head.appendChild(script);

        // If Jitsi fails for some reason, that should not block the
        // text-only connection from being established properly.
        script.onload = () => { jitsiScriptLoaded = true; jitsiReconnect() };
    }

    // This shouldn't be called until the Jitsi external API script loads
    function jitsiReconnect() {
        // Script not loaded? Bail.
        if(!jitsiScriptLoaded) {
            return;
        }

        // Already have a connection? Kill it.
        if(jitsiAPI) {
            jitsiAPI.dispose();
            jitsiAPI = undefined;
            document.querySelector("#audio_room").textContent = "(none)";
        }

        // Disconnecting? Then we're no longer effectively mid-mute.
        jitsiMidMute = false;

        // Want to be silent? Just don't reconnect. We don't currently allow send-only.
        if(jitsiSilenced) {
            console.log("Reconnect: jitsi is silenced, so skip connection/reconnection.");
            return;
        }

        if(!jitsiRoom || !jitsiToken) {
            console.log("Reconnect: no room and/or token specified, so don't connect/reconnect.");
            return;
        }

        // Jitsi Setup - for more Jitsi, see: https://jitsi.github.io/handbook/docs/dev-guide/dev-guide-iframe
        // For list of config options: https://github.com/jitsi/jitsi-meet/blob/master/config.js
        const options = {
            roomName: jitsiRoomPrefix + jitsiRoom,
            width: 200,
            height: 200,
            parentNode: document.querySelector('#meet'),
            configOverwrite: { startSilent: false, startWithAudioMuted: jitsiClientMuted || jitsiServerMuted, fileRecordingsEnabled: false },
            jwt: jitsiToken,
            userInfo: {
                displayName: jitsiNickname
            }
        };
        jitsiAPI = new JitsiMeetExternalAPI(jitsiDomain, options);
        document.querySelector("#audio_room").textContent = jitsiRoom;
        //jitsiAPI.getAvailableDevices().then(devices => updateAudioInputs(devices));
    }

    //// If you call this yourself, it messes things up. Please don't.
    //function updateAudioInputs(devices) {
    //  console.log("Updating audio input device list...");
    //  var selector = document.querySelector('#audio_input_devices');
    //  while(selector.options.length > 0) { selector.remove(0); }
    //  devices.audioInput.forEach(dev => {
    //      var opt = document.createElement('option');
    //      opt.value = dev.label;
    //      opt.title = dev.label;
    //      if(dev.label.length > 10) {
    //          opt.text = dev.label.slice(0,9) + "...";
    //      } else {
    //          opt.text = dev.label;
    //      }
    //      opt.deviceId = dev.deviceId;
    //      selector.add(opt);
    //      });
    //  if(!jitsiAddedAudioInputListener) {
    //      jitsiAddedAudioInputListener = true;
    //      selector.addEventListener('change', (event) => {
    //          console.log("Audio input device selector: changed");
    //          if(selector.value != jitsiLastAudioDevice) {
    //              console.log("Setting Jitsi audio input: " + selector.value)
    //              jitsiAPI.setAudioInputDevice(selector.value);
    //              jitsiLastAudioDevice = selector.value;
    //          } else {
    //              console.log("Audio device not changed from " + jitsiLastAudioDevice + ", not setting...");
    //          }
    //      });
    //  }
    //}

    function toggleClientMuted() {
        console.log("toggleClientMuted", jitsiClientMuted);
        jitsiClientMuted = !jitsiClientMuted;
        muteUnmute();
    }

    // Silenced means the user has asked the client to not connect.
    function toggleSilenced() {
        console.log("toggleSilenced", jitsiSilenced);
        jitsiSilenced = !jitsiSilenced;

        updateSilencedUI();

        // Jitsi can't silence/unsilence after loading. So we just connect or not, basically.
        // It's also possible to keep a Jitsi connection but with no local output. But why?
        jitsiReconnect();
    }

    function updateSilencedUI() {
        let settingsDiv = document.querySelector("#audio_settings");
        let silenceButton = document.querySelector("#silence_button");
        if(jitsiSilenced) {
            settingsDiv.classList = "silenced";
            silenceButton.classList = "fas fa-volume-mute";
        } else {
            settingsDiv.classList = "audible";
            silenceButton.classList = "fas fa-volume-up";
        }
    }

    function updateMutedUI() {
        let muteButton = document.querySelector('#mute_button');
        if(jitsiClientMuted) {
            muteButton.classList = "muted fas fa-microphone-alt-slash";
        } else {
            muteButton.classList = "unmuted fas fa-microphone-alt";
        }

        let chatIndicator = document.querySelector("#chat_indicator");
        if(jitsiServerMuted) {
            chatIndicator.classList = "muted";
        } else {
            chatIndicator.classList = "unmuted";
        }
    }

    function muteUnmute() {
        updateMutedUI();

        if(jitsiSilenced) {
            // Silenced normally means disconnected, so don't tell Jitsi whether to mute.
            return;
        }

        if(!jitsiMidMute) {
            jitsiMidMute = true;
            jitsiAPI.isAudioMuted().then(muted => updateMuteState(muted));
        }
    }

    // If you call this yourself, it messes things up. Please don't.
    function updateMuteState(muted) {
        jitsiMidMute = false;

        let shouldBeMuted = jitsiServerMuted || jitsiClientMuted;

        if(shouldBeMuted != muted) {
            jitsiAPI.executeCommand('toggleAudio');
        }
    }

    function updateCompass(bitfield, image, dir, bit) {

        if (bitfield & bit) {
            image.style.backgroundImage = "url(http://images.gables.chattheatre.com/arrows/" + dir + "-ex.gif)";
        } else {
            image.style.backgroundImage = "url(http://images.gables.chattheatre.com/arrows/" + dir + "-noex.gif)";
        }
    }
//-----Component Functionality
    function doSkoot(num, msg) {
        num = Number(num);
        console.log("SKOOT " + num + " " + msg);
        switch (num) {
        case 1:
            var img = document.getElementById("image_map_img");
            if (img) {
                img.style.backgroundImage = "url('"+msg+"')";
            } else {
                badSkoot(num, msg);
            }
            break;
        case 2:
            popupArtWin(msg, "Art", "Skotos Art");
            break;
        case 3:
            badSkoot(num, msg);
            break;
        case 4:
            bigMapHREF = msg;
            break;
        case 5:
            updateCompass(msg, document.getElementById("comp_n"), "n",    1);
            updateCompass(msg, document.getElementById("comp_ne"), "ne",   2);
            updateCompass(msg, document.getElementById("comp_e"), "e",    4);
            updateCompass(msg, document.getElementById("comp_se"), "se",   8);
            updateCompass(msg, document.getElementById("comp_s"), "s",   16);
            updateCompass(msg, document.getElementById("comp_sw"), "sw",  32);
            updateCompass(msg, document.getElementById("comp_w"), "w",   64);
            updateCompass(msg, document.getElementById("comp_nw"), "nw", 128);
            break;
        case 6:
            popupWin(msg, "SkotosAnyURL", 800, 600);
            break;
        case 7:
            showCompass(msg);
            break;
        case 8:
            showStatusBar(msg);
            break;
        case 9:
            showEnvIcon(msg);
            break;
        case 10:
            showHVMapLinks(msg);
            break;
        case 21:
            // This is for a player or similar creature entering
            break;
        case 70:
            popupWin(msg, "SkotosToolSourceView", 800, 600);
            break;

        case 80:
            // What will need changing after this message?
            let doReconnect = false;
            let doMuteUnmute = false;

            // Server-sent Jitsi information
            var s = JSON.parse(msg);
            console.log("New Jitsi settings:", s);

            // Fields not yet set or used: email, avatar.

            // If jitsiDomain wasn't set, this is the first Jitsi SKOOT message.
            if(!jitsiDomain) {
                console.log("First Jitsi message - initialising Jitsi...")
                if(!s.domain || !s.name) {
                    console.log("Internal error: Jitsi SKOOT message must always set jitsi domain and display name!");
                    badSkoot(num, msg);
                    break;
                }
                jitsiDomain = s.domain;
                jitsiNickname = s.name;
                jitsiRoomPrefix = "";
                if(s.roomPrefix) {
                    jitsiRoomPrefix = s.roomPrefix;
                }
                jitsiServerMuted = (s.muted == "muted");

                // If s.room is undefined, don't connect to a room (yet?)
                jitsiRoom = s.room;
                jitsiToken = s.jwt;

                doReconnect = true;
            } else {
                // If it's *not* the first Jitsi SKOOT message, there's a lot we expect not to change.

                // One way Jitsi handles versioning is that the external API script is loaded
                // from the same Jitsi server. So if we'd switch domains, we have to reload the
                // script, which means reloading this page.
                if(s.domain && s.domain != jitsiDomain) {
                    console.log("Jitsi domain changed", s.domain, jitsiDomain);
                    alert("Jitsi domain has changed from " + jitsiDomain + " to " + s.domain + "! Please reload this page!");
                    break;
                }

                // Jitsi could, in theory, handle this just fine. But it's a very bad sign if this happens.
                // The server should be assigning us the same Jitsi display name in every channel.
                if(s.name && s.name != jitsiNickname) {
                    console.log("Nickname mismatch", s.name, jitsiNickname);
                    alert("Orchil Jitsi error! Server nickname " + s.name + " changed from nickname " + jitsiNickname + "!");
                    break;
                }

                // Jitsi handles this fine, but you still wouldn't expect it to happen.
                if(s.roomPrefix && s.roomPrefix != jitsiRoomPrefix) {
                    console.log("Weird! Jitsi room prefix changed", s.roomPrefix, jitsiRoomPrefix);
                    doReconnect = true;
                }
            }

            // Muted is a trinary muted/unmuted/null - if muted is not given, retain the
            // previous setting.
            if(s.muted) {
                if(s.muted != "muted" && s.muted != "unmuted") {
                    console.log("SKOOT 80 'muted' setting should be 'muted' or 'unmuted'; instead was:", s.muted);
                    badSkoot(num, msg);
                    break;
                }

                newMuted = (s.muted == "muted");
                if(jitsiServerMuted != newMuted) {
                    jitsiServerMuted = newMuted;
                    doMuteUnmute = true;
                }
            }

            // The server can specify a new room and token.
            // If no room is received, stick with the same room and token.
            // Note that a reconnect isn't guaranteed
            // to work if our JWT token has expired...
            if(s.room && s.room != jitsiRoom) {
                //console.log("Setting room and token...", s.room, s.jwt);
                jitsiRoom = s.room;
                jitsiToken = s.jwt;
                if(!jitsiToken) {
                    console.log("Internal error: Server assigned Jitsi room " + jitsiRoom + " but no JWT token!");
                    badSkoot(num, msg);
                    break;
                }
                doReconnect = true;
            }

            // Init handles reconnect automatically, reconnect handles mute/unmute.
            if(!jitsiCalledInit) {
                // Even if we have no Jitsi room, call init to start loading the external API script.
                initJitsi();
            } else if(doReconnect) {
                jitsiReconnect();
            } else if (doMuteUnmute) {
                muteUnmute();
            }

            break;

        default:
            badSkoot(num, msg);
        }
    }
    function popupMapWindow() {
            popupArtWin(bigMapHREF, 'Map', 'Gables Overview Map');
    }
    function compassArrow(direction) {
        sendUI('go ' + direction);
    }
    function showCompass(str) {
        var arr = (str.split(","));
        for (var i=0; i<arr.length; i=i+2) {
            if(arr[i+1] == 'show') {
                document.getElementById('comp_'+arr[i]).style.opacity = 0.8;
                document.getElementById('comp_'+arr[i]).style.background = '#ffffff';
            } else {
                document.getElementById('comp_'+arr[i]).style.opacity = 0.5;
                document.getElementById('comp_'+arr[i]).style.background = '#aaaaaa';
            }
        }
    }
    function showStatusBar(str) {
        var arr = (str.split(","));
        var filler = document.getElementById('fill_'+arr[0].toLowerCase());
        if (filler) {
            filler.style.height = (arr[1]*0.75) + "px";
        }
    }
    function showEnvIcon(str) {
        var i= Math.min(Math.max(str*1, 0), 30); //0-30
        i = Math.round((i / 30) * 100) / 100;    //No more than two decimal points
        document.getElementById('light_indicator').style.opacity = i;
    }
    //-----Map Functions
        function createMapDiv(id, parentId, className) {
            var div = document.createElement("div");
            div.id = id;
            div.className = className;
            document.getElementById(parentId).appendChild(div);
            return div;
        }
        function createMapImg(parentObj, className, src) {
            var img = document.createElement("img");
            img.className = className;
            parentObj.appendChild(img);
            img.src = src;
            img.alt = '';
            return img;
        }
        function findOrCreateRoom(id) {
            var room = document.getElementById('maproom' + id);
            if (!room) {
                room = createMapDiv('maproom' + id, 'map_area', 'maproom');
            }
            return room;
        }
        function findOrCreateLink(dir, id) {
            var link = document.getElementById(id);
            if (!link) {
                if (dir == 'hor' || dir == 'ver') {
                    link = createMapDiv(id, 'map_area', 'map_link_' + dir);
                } else if (dir == 'ne') {
                    link = createMapDiv(id, 'map_area', 'map_link_dia');
                    createMapImg(link, 'map_link_dia_tr', 'sw4.gif');
                    createMapImg(link, 'map_link_dia_bl', 'ne4.gif');
                } else if (dir == 'nw') {
                    link = createMapDiv(id, 'map_area', 'map_link_dia');
                    createMapImg(link, 'map_link_dia_tl', 'se4.gif');
                    createMapImg(link, 'map_link_dia_br', 'nw4.gif');
                } else if (dir == 'none') {
                    link = createMapDiv(id, 'map_area', 'map_link_dia');
                    createMapImg(link, 'map_link_dia_tr', 'nosw.gif');
                    createMapImg(link, 'map_link_dia_bl', 'none.gif');
                } else if (dir == 'nonw') {
                    link = createMapDiv(id, 'map_area', 'map_link_dia');
                    createMapImg(link, 'map_link_dia_tl', 'nose.gif');
                    createMapImg(link, 'map_link_dia_br', 'nonw.gif');
                }
            }
            return link;
        }

        function showMap(str) {
            var arr = (str.split(","));
            var i = 0;
            var x, y, wid, bg, col, lig, colarr;
            var locwid = 120 * 0.5;
            var id;
            clearMap();
            clearMapLinks();
            for (i; i < arr.length; i = i + 5) {
                wid = arr[i + 2]*1;
                col = arr[i + 3];
                lig = Math.min(Math.max(arr[i + 4], 0), 30);
                lig = lig - 25;
                colarr = col.hex2rgb();
                colarr[0] = Math.min(Math.max(Math.round(colarr[0]*1 + (lig * 8)), 0), 255);
                colarr[1] = Math.min(Math.max(Math.round(colarr[1]*1 + (lig * 8)), 0), 255);
                colarr[2] = Math.min(Math.max(Math.round(colarr[2]*1 + (lig * 8)), 0), 255);
                col = colarr.join(",").rgb2hex();
                x = arr[i]*1 + locwid;
                y = arr[i + 1]*1 + locwid;
                id = ((i+5)/5);
                var room = findOrCreateRoom(id);
                room.style.left       = x + "px";
                room.style.top        = y + "px";
                room.style.width      = (wid - 2)  + "px";
                room.style.height     = (wid - 2)  + "px";
                room.style.background = col+'';
            }
        }

        function showHVMapLinks(str) {
            var arr = (str.split(","));
            var i, x, y, dir, acc, link;
            var id, ver=0, hor=0, nw=0, ne=0, nonw=0, none=0, num;
        //  var locwid = document.getElementById("map_area").style.width.replace("px", "")*0.5;
            var locwid = 120 * 0.5;

            for (i = 0; i < arr.length; i = i + 4) {
                x = arr[i]*1 + locwid;
                y = arr[i + 1]*1 + locwid;
                dir = arr[i + 2];
                acc = arr[i + 3]*1;

                //x,y,ver,1
                if (dir != 'ver' && dir != 'hor' && !acc) {
                    dir = 'no'+dir;
                }

                if (dir == 'ver') {
                    ver++;
                    x = x - 2 - x/80;
                    y = y - 3 - y/20;
                    id = "maplink" + dir +''+ ver;
                } else if (dir == 'hor') {
                    hor++;
                    x = x - 3 - x/40;
                    y = y - 2;
                    id = "maplink" + dir +''+ hor;
                } else {
                    if (dir == 'nw') {
                        nw++;num = nw;
                    } else if (dir == 'ne') {
                        ne++;num = ne;
                    } else if (dir == 'nonw') {
                        nonw++;num = nonw;
                    } else if (dir == 'none') {
                        none++;num = none;
                    }
                    x = x - 5;
                    y = y - 5;
                    id = "maplink" + dir +''+ num;
                }
                link = findOrCreateLink(dir, id);
                if (dir == 'ver' || dir == 'hor') {
                    if (acc) {
                        link.style.background = '#ffffff';
                    } else {
                        link.style.background = '#000000';
                    }
                }
                link.style.left = x + "px";
                link.style.top = y + "px";
            }
        }

        function clearMap() {
            for (var i=1;;i++) {
                var room = document.getElementById('maproom' + i);
                if (!room) {
                    return;
                }
                if (room.offsetTop == -30 && room.offsetLeft == -30) {
                    return;
                }
                room.style.left   = -30 + "px";
                room.style.top    = -30 + "px";
                room.style.width  = 0;
                room.style.height = 0;
                room.style.background = 'transparent';
            }
        }

        function clearMapLinks() {
            var linknames = ['maplinkver', 'maplinkhor', 'maplinkne', 'maplinknw', 'maplinknone', 'maplinknonw'];
            var numnames = linknames.length;
            for (var i=1;;i++) {
                var link, found;
                found = 0;
                for (var j=0;j<numnames;j++) {
                    link = document.getElementById(linknames[j] + i);
                    if (link) {
                        link.style.left  = -30 + "px";
                        link.style.top   = -30 + "px";
                        found = 1;
                    }
                }
                if (!found) {
                    return;
                }
            }
        }
//-----Library Functions
    function romanize(num) {
        if (!+num) return false;
        var digits = String(+num).split(''),
            key = ['','C','CC','CCC','CD','D','DC','DCC','DCCC','CM', '','X','XX','XXX','XL','L','LX','LXX','LXXX','XC', '','I','II','III','IV','V','VI','VII','VIII','IX'], roman = '',
            i = 3;
        while (i--)
            roman = (key[+digits.pop() + (i * 10)] || '') + roman;
        return Array(+digits.join('') + 1).join('M') + roman;
    }
    String.prototype.hex2rgb = function() {
        var red, green, blue;
        var triplet = this.toLowerCase().replace(/#/, '');
        var rgbArr  = new Array();

        if(triplet.length == 6) {
            rgbArr[0] = parseInt(triplet.substr(0,2), 16)
            rgbArr[1] = parseInt(triplet.substr(2,2), 16)
            rgbArr[2] = parseInt(triplet.substr(4,2), 16)
            return rgbArr;
        } else if(triplet.length == 3) {
            rgbArr[0] = parseInt((triplet.substr(0,1) + triplet.substr(0,1)), 16);
            rgbArr[1] = parseInt((triplet.substr(1,1) + triplet.substr(1,1)), 16);
            rgbArr[2] = parseInt((triplet.substr(2,2) + triplet.substr(2,2)), 16);
            return rgbArr;
        } else {
            throw triplet + ' is not a valid color triplet.';
        }
    }
    function rgb2hexfun(value) {
        var x = 255;
        var hex = '';
        var i;
        var regexp=/([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/;
        var array=regexp.exec(value);
        for(i=1;i<4;i++) hex += ('0'+parseInt(array[i]).toString(16)).slice(-2);
        return '#'+hex;
    }
    String.prototype.rgb2hex = function() {
        var x = 255;
        var hex = '';
        var i;
        var regexp=/([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/;
        var array=regexp.exec(this);
        for(i=1;i<4;i++) hex += ('0'+parseInt(array[i]).toString(16)).slice(-2);
        return '#'+hex;
    }

    function popupArtWin(filename, windowname, windowtitle) {
        var artwin;
        var adj4NN  = (navigator.appName == "Netscape" ? -5 : 0 );
        var scrLeft = 16 + window.screenX;
        var scrTop  = 16 + window.screenY;

        var i = filename.indexOf(' ');
        while (i != -1) {
            filename = filename.substring(0, i) + '%20' +
                    filename.substring(i + 1);
            i = filename.indexOf(' ');
        }

        artwin = window.open('http://game.gables.chattheatre.com/Theatre/Art.sam?url=' +
                                 escape(filename) + '&title=' +
                 escape(windowtitle), windowname,
                 'width=100,height=100,left=' + scrLeft +
                                 ',top=' + scrTop +
                 ',hotkeys=no,scrollbars=no,resizable=no,' +
                 'dependent=yes');
        // Just in case it was already open and not at the foreground.
        artwin.focus();
    }

    connDisconnected = function() {
        if(jitsiAPI) {
            jitsiAPI.dispose();
        }
        parentDisconnected();
    }

//-----Initialization Code, used for log filename
    var serverCode = "SkotOS";
