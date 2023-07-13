/*##############################################################################
# File: startup.js                                                             #
# Project: myzap2.0                                                            #
# Created Date: 2021-06-27 02:34:00                                            #
# Author: Eduardo Policarpo                                                    #
# Last Modified: 2021-07-11 00:35:56                                           #
# Modified By: Eduardo Policarpo                                               #
##############################################################################*/

import SessionsDB from "./firebase/model.js";
import { snapshot} from './firebase/db.js';
import request from "request-promise";
import config from "./config.js";
import { existsSync } from 'node:fs';
import fs from 'fs';
import path from 'path'

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
  
async function getAllSessions(force) {
    try {
        const SessionsArray = [];
	if(config.apikey === undefined ) {
	 console.log('Lendo dos dados locais...')
	 let directoryPath='./tokens';
	 let files=fs.readdirSync(directoryPath)
	 console.log(files)
	 for(const file of files) {
	   //console.log('Processando diretorio: ' + file);
	      let stats = fs.statSync(path.join(directoryPath, file))
	      if (stats.isDirectory()) {
		  console.log('Processando diretorio ' + file)
		  let arquivo = directoryPath + '/' + file + '/session.js';
		  if(existsSync(arquivo)){
		    console.log('Arquivo existe: ' + arquivo)
		    
		    let data=fs.readFileSync(arquivo, 'utf8')
		    try {
		      const objeto = JSON.parse(data);
		      console.log(objeto);
		      SessionsArray.push(objeto)
		      console.log(SessionsArray)
		    } catch (err) {
		      console.error('Erro ao analisar o JSON', err);  
		    }
		  }		
	       }
	  }  	  
	      

	} else {
	  if (snapshot.empty) {
            return null;
	  } else {
	    console.log(`Reading ${config.sessions_field} from database`)
	    
            snapshot.forEach(doc => {
                const Session = new SessionsDB(
                    doc.id,
                    doc.data().session,
                    doc.data().apitoken,
                    doc.data().sessionkey,
                    doc.data().wh_status,
                    doc.data().wh_message,
                    doc.data().wh_qrcode,
                    doc.data().wh_connect,
                    doc.data().WABrowserId,
                    doc.data().WASecretBundle,
                    doc.data().WAToken1,
                    doc.data().WAToken2,
                    doc.data().Engine,
		    doc.data().timeout,
                );
		if(force==='true' || existsSync('./tokens/' + doc.data().session)) {			   
                   SessionsArray.push(Session);
		}
            });
	 }
	}
	await console.log('Retornando ' + SessionsArray)

        return (SessionsArray);        

    } catch (error) {
        return (error.message);
    }
}

async function startAllSessions(force) {
    let dados = await getAllSessions(force)
    console.log('Dados: ' + dados)
//    return
    if (dados != null) {
        if (dados === 'Missing or insufficient permissions.') {
            console.log('######### ERRO DE CONFIGURACAO NO FIREBASE #########')
            console.log('####### Missing or insufficient permissions. #######')
            console.log('### Verifique as permissões de escrita e leitura ###')
        } else {
	    for(const item of dados){
	        console.log('Iniciando sessão: ' + item)
                var options = {
                    'method': 'POST',
                    'json': true,
                    'url': `${config.host}/start`,
                    'headers': {
                        'apitoken': item.apitoken,
                        'sessionkey': item.sessionkey
                    },
                    body: {
                        "session": item.session,
			"timeout": item.timeout,
                        "wh_connect": item.wh_connect,
                        "wh_qrcode": item.wh_qrcode,
                        "wh_status": item.wh_status,
                        "wh_message": item.wh_message
                    }

                };
                request(options).then(result => {
                    console.log(result)
                }).catch(error => {
                    console.log(error)
                })
		await sleep(10000)
            }
        }
    }
}

const startallsessionsEx = async function (req, res) {
   console.log('starting all sessions')
   
   startAllSessions(true);
   
   return res.status(200).json({
	result: 200,
        "status": "OK"
     })
}

export default { startAllSessions,  startallsessionsEx };

export { startallsessionsEx }