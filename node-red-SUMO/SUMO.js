/**
 * Copyright 2016 IBM Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

module.exports = function(RED)
{
	"use strict";
	var spawn = require('child_process').spawn;

	function SUMO(n)
	{
		RED.nodes.createNode(this,n);
		this.matlabd = n.matlabd;
		var node = this;

		this.on("input", function(msg)
		{
			node.status({fill:"green", shape:"dot", text:"executing"});

			var SUMO_files = msg.payload;

			// split array of messages
			if (Array.isArray(SUMO_files))
			{
				var sampleSet_array = [];

				var i = 0;
				var refreshIntervalId = setInterval(function()
				{
					// matlabd argument list
					var arg = "[newSample HV_PoI] = BMoptMOSBO('" + SUMO_files[i].filename + "')";
					arg = arg.match(/(?:[^\s"]+|"[^"]*")+/g);

					// Run the SUMO optimizer using matlab daemon
					node.child = spawn(node.matlabd, arg);

					// SUMO sends normal data
					node.child.stdout.on('data', function (data)
					{
						// buf2str
						data = data.toString();

						// Parse sampleSet and Hyper Volume Probability of Improvement (HV_PoI) parameters
						var sampleSet = data.substring(data.lastIndexOf("newSample =") + 11, data.lastIndexOf("HV_PoI =")).trim();
						sampleSet = sampleSet.split(" ").filter(function(e){return e;});
						var HV_PoI = data.substring(data.lastIndexOf("HV_PoI =") + 8).trim();

						// If SUMO sends a new sampleSet, store it in an array
						if(typeof(sampleSet) !== "undefined")
							sampleSet_array.push(sampleSet);

						// Did SUMO sent all sample sets?
						if(sampleSet_array.length >= SUMO_files.length)
						{
							msg.payload = sampleSet_array;

							node.status({});
							node.send([msg, null]);
						}
					});

					// SUMO sends error data
					node.child.stderr.on('data', function (data)
					{
						var msg = {payload: data.toString()};

						node.status({fill:"red", shape:"dot", text:"SUMO stderr"});
						node.send([null, msg]);
					});

					node.child.on('close', function (code)
					{
						node.child = null;
					});

					// matlabd execution error
					node.child.on('error', function (err)
					{
						if(err.errno === "ENOENT")
							node.warn('SUMO: command not found');
						else if(err.errno === "EACCES")
							node.warn('SUMO: command not executable');
						else
							node.log('SUMO: error: ' + err);
					});


					if(i == SUMO_files.length - 1)
						clearInterval(refreshIntervalId);

					i++;
				}, 10);
			}
			// Message was not an array, display error message
			else
			{
				node.status({fill:"red", shape:"dot", text:"Error"});
				node.send([null, "SUMO: payload must be array of filenames"]);
			}
		});
	}
	RED.nodes.registerType("SUMO",SUMO);
}
