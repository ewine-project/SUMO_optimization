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

	function MATLABd(n)
	{
		RED.nodes.createNode(this,n);
		this.matlabd = n.matlabd;
		var node = this;

		this.on("input", function(msg)
		{
			node.status({fill:"green", shape:"dot", text:"executing"});


			// Run command using matlab daemon
			var arg = msg.payload.match(/(?:[^\s"]+|"[^"]*")+/g);
			node.child = spawn(node.matlabd, arg);

			// MATLABd sends normal data
			node.child.stdout.on('data', function (data)
			{
				var msg = {payload: data.toString()};

				node.status({});
				node.send([msg, null]);
			});

			// MATLABd sends error data
			node.child.stderr.on('data', function (data)
			{
				var msg = {payload: data.toString()};

				node.status({fill:"red", shape:"dot", text:"MATLABd stderr"});
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
					node.warn('MATLABd: command not found');
				else if(err.errno === "EACCES")
					node.warn('MATLABd: command not executable');
				else
					node.log('MATLABd: error: ' + err);
			});
		});
	}
	RED.nodes.registerType("MATLABd",MATLABd);
}
