#!/bin/bash
#
# manageEndpoint - Retorna o apontamento do servico com a possibilidade de alterar e gravar em um arquivo para manter um historico de alteracoes
#
# Como usar: manageEndpoint adapter nomedoservico
#            manageEndpoint (o script pergunta os parametros caso nenhum dado seja passado)
#
# Exemplo:
#             manageEndpoint http F_CRM_QYSRACTDES
#             manageEndpoint
#
# Historico de versoes:
#       Versão: 1.0
#             Autor: Felipe de Carvalho Alencar <felipe.alencar@engdb.com.br>
#             Data: 05/2020
#             Descrição: Primeira versao.
#
#		Versão: 1.1
#             Autor: Felipe de Carvalho Alencar <felipe.alencar@engdb.com.br>
#             Data: 06/2020
#             Descrição: Adicao para a consulta e alteracao de serviços ib-ejb e melhora da logica para diminuicao de linhas de comando
#

#caso nenhum parametro seja inserido o script pergunta os parametros
if [ -z $1 ] || [ -z $2 ]
then
        read -p "Adapter: " tipoAdapter
        read -p "Service: " servicename
else
        tipoAdapter=$1
        servicename=$2
fi

#transforma a entrada para letras minusculas 
adapterToLower=$(echo ${tipoAdapter} | awk '{ print tolower($1) }')

#valida qual tipo de adapter foi inserido
case ${adapterToLower} in

        http)	   
#funcao para coletar host, port e uri do arquivo adapters.temp
			    tipoHttp() {
						host=`grep -w "hostname" adapters.temp | grep "tsw/pools" | grep -w "${adapter}${servicename}" | cut -d "=" -f2-`
                        port=`grep -w "port" adapters.temp | grep "tsw/pools" | grep -w "${adapter}${servicename}" | cut -d "=" -f2-`
                        uri=`grep -w "uri" adapters.temp | grep -w "${servicename}" | cut -d "=" -f2-`
				}
#valida qual padrao o servico se encaixa e coleta o hostname, port e uri que serao mostrado ao usuario
                ppk adapter/http/tsw | grep ${servicename} > adapters.temp

                                if [ `grep -w "hostname" adapters.temp | grep -cw "HTTP_${servicename}"` -eq 1 ]
                                then
                                    adapter="HTTP_"
									tipoHttp
									
                                elif [ `grep -w "hostname" adapters.temp | grep -cw "SAL_HTTP_${servicename}"` -eq 1 ]
                                then
                                    adapter="SAL_HTTP_"	
									tipoHttp
									
                                else
									tipoHttp
									adapter="isNormalHTTP"
                                fi
                echo ""
                endpoint=`echo "${host}:${port}${uri}"`
                echo "Endpoint: "${endpoint}
                echo ""
        ;;

        webservice|web)
#aplica um comando para trazer apenas o apontamento completo do servico
                adapter="isWebservice"
                echo ""
                endpoint=`ppk adapter/webservice/tsw/methods | grep -w "${servicename}" | grep target | cut -d "=" -f2-`
                echo "Endpoint:" ${endpoint}
                echo ""
        ;;
#retorna a procedure e datasource do para um servico DB
        db)
                adapter="isDB"
                ppk adapter/db/tsw/methods | grep -w "${servicename}" > adapters.temp
                echo ""
                endpoint=`echo "Procedure: " $(grep -w statement adapters.temp | cut -d "=" -f2-); echo "Datasource: " $(grep -w datasource adapters.temp | cut -d "=" -f2-)`
                echo "Procedure: " $(grep -w statement adapters.temp | cut -d "=" -f2-)
                echo "Datasource: " $(grep -w datasource adapters.temp | cut -d "=" -f2-)
                echo ""
        ;;
#retorna o endpoint completo para um servico ib-ejb, mesmo que seja inserido o nome do alias do servico	
        ibejb|ib-ejb|ejb)
		
				adapter="isEJB"
				echo ""
				ppk adapter/ib-ejb | grep -w "${servicename}" > adapters.temp
				isAlias=`grep endpoint adapters.temp | wc -l`
					if [ "${isAlias}" == "0" ]; then
						svcAlias=`grep service adapters.temp | cut -d "/" -f4`
						ppk adapter/ib-ejb | grep -w "${svcAlias}" > adapters.temp
						echo ${servicename} "é um alias do serviço" ${svcAlias}
					fi
				servicename=${svcAlias}
				endpoint=`grep "endpoint" adapters.temp | cut -d "=" -f2-`
				echo "Endpoint: " ${endpoint}
				echo ""
        ;;

        *)
#caso nao passar nenhum parametro procura da forma antiga
                ppk adapter | grep ${servicename}
        ;;
esac


#grava as alteracoes no arquivo de historico de alteracoes 
record () {
        echo -e " $(date) - INF ${inf} - ${servicename} \n De:   ${endpoint} \n Para: ${newEndpoint} \n\n" >> trocas_INF.txt

        echo ""
        echo "Alteracao realizada. Estara disponivel apos o sinc e restart."
        echo ""
}

#aplica a alteracao no ambiente como no script "set-key-prefs.sh" passando o caminho completo. Trecho retirado do script citado.
setPrefs () {
	if [ "$IB_WLS_HOME" != "" ]; then
			export INFOBUS_HOME=$IB_WLS_HOME
	fi
	if [[ "$INFOBUS_HOME" = "" ]]; then
			if [[ -s $HOME/lib/MWIBRepository.jar ]]; then
			export INFOBUS_HOME=$HOME
			else
				echo "This is not a INFOBUS environment variable was not set."
				echo "Please, do set INFOBUS_HOME=<where-infobus-structure-was-installed> before"
				exit 1
			fi
	fi
	
	# Add the required jars to CLASSPATH to execute script
	for comp in Repository Log Context Exception
	do
			CLASSPATH=$CLASSPATH:$INFOBUS_HOME/lib/MWIB${comp}.jar
	done
	java -cp $CLASSPATH IBPrefsSetParam ${path}=${new}
}

#as funcoes abaixo definem o fluxo para alteracao ou nao de host, port e uri para servicos http

Uri () {
        read -p "Alterar URI? (y / n):  " altUri
}

Port () {
        read -p "Alterar port? (y / n):  " altPort
        if [ ${altPort} != "y" ]
        then
                Uri
        fi

}

Host () {
        read -p "Alterar host? (y / n):  " altHost
        if [ ${altHost} != "y" ]
        then
                Port
        fi
}

read -p "Deseja alterar o apontamento? (y / n):  " decision

#validacao para qual fluxo o script deve seguir com base no adapter do servico, em seguida define os caminhos e quais serao os novos parametros para a alteracao
if [ ${decision} == "y" ]
then
        read -p "Insira o número da INF: " inf
        case ${adapter} in
                        isWebservice)

                                        read -p "Insira o novo apontamento completo: " new
                                        echo ""
                                        path=`ppk adapter/webservice/tsw/methods | grep -w "${servicename}" | grep target | cut -d "=" -f1`
                                        newEndpoint=${new}
                                        setPrefs
                                        record
                        ;;

                        SAL_HTTP_|HTTP_|isNormalHTTP)
						
								if [ ${adapter} == "isNormalHTTP" ]
								then
									adapter=""
								fi
								
                                Host
                                if [ ${altHost} == "y" ]
                                then
                                        read -p "Insira o novo host: " new
                                        echo ""
                                        path=`grep -w "hostname" adapters.temp | grep "tsw/pools" | grep -w "${adapter}${servicename}" | cut -d "=" -f1`
                                        setPrefs
                                        Port
                                        host=${new}
                                fi

                                if [ ${altPort} == "y" ]
                                then
                                        read -p "Insira o novo port: " new
                                        echo ""
                                        path=`grep -w "port" adapters.temp | grep "tsw/pools" | grep -w "${adapter}${servicename}" | cut -d "=" -f1`
                                        setPrefs
                                        Uri
                                        port=${new}
                                fi

                                if [ ${altUri} == "y" ]
                                then
                                        read -p "Insira o novo URI (com a barra "/" no início): " new
                                        echo ""
                                        path=`grep -w "uri" adapters.temp | grep "tsw/methods" | grep -w "${servicename}" | cut -d "=" -f1`
                                        setPrefs
                                        uri=${new}
                                fi
                                newEndpoint=`echo "${host}:${port}${uri}"`
                                record
                        ;;

                        isDB)
#como nao temos alteracao de procedure esse ponto sera adicionado quando necessario
                                echo "alterar procedure? wtf"
                        ;;
												
						isEJB)
                                        read -p "Insira o novo apontamento completo: " new
                                        echo ""
                                        path=`grep endpoint adapters.temp | cut -d "=" -f1`
                                        newEndpoint=${new}
                                        setPrefs
                                        record
                        ;;
        esac

else
        exit 0
fi
