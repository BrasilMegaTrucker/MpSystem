/*
    Sistema de mensagens privadas - básico em MySQL
    Necessário alterar os dados de conexão para que funcione corretamente
*/

#include a_samp
#include a_http
#include sscanf2
#include a_mysql
#include zcmd

#undef MAX_PLAYERS
#define MAX_PLAYERS 101 // Altere para o número de slots desejado

#define URL_EMAIL "br-me.net/publico/email.php"
#define EMAIL_ENVIO "notificacao@br-me.net"

/******************************************************************************/
/************************ Dados de conexão ************************************/
/******************************************************************************/
#define     MYSQL_HOST          ""                 // Seu host MySQL
#define     MYSQL_USER          ""                      // Usuário MySQL
#define     MYSQL_PASS          ""                          // Senha
#define     MYSQL_DB            ""                 // Database
/******************************************************************************/
/******************************************************************************/

new con_mysql; // Armazena o ID da conexão
new http_request; // Este ID irá aumentar de forma automática de acordo com as requesições

enum pInf
{
    mID,
    Email[128],
    bool:Bloqueado,
    NovasMsg,

    // Pagina
    pagList
};
new pData[MAX_PLAYERS][pInf];

#define DialogOpMsg         15240
#define DialogMsgEnviada    15241
#define DialogMsgRecebida   15242
#define DialogMsgNaoLidas   15243
#define DialogMsgRetorno    15244
#define DialogDefinirEmail  15245

public OnFilterScriptInit() {
    print("Sistema de mensagens privadas: CARREGADO");
    con_mysql = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASS);
    if(mysql_errno(con_mysql)) return print("OCORREU UM ERRO DURANTE A TENTATIVA DE CONEXÃO COM A DB!");

    // Criar as tabelas
    mysql_query(con_mysql, "CREATE TABLE IF NOT EXISTS `mp_contas` (`id` int(11) NOT NULL,`user` varchar(24) NOT NULL,`novas_mensagens` int(11) NOT NULL,`email` varchar(128) NOT NULL)ENGINE=MyISAM DEFAULT CHARSET=utf8;", false);
    mysql_query(con_mysql, "CREATE TABLE IF NOT EXISTS `mp_msgs` (`id` int(11) NOT NULL AUTO_INCREMENT,`de_contaid` int(11) NOT NULL,`para_contaid` int(11) NOT NULL,`horario` int(11) NOT NULL,`data` varchar(20) NOT NULL,`lida` int(11) NOT NULL,`Mensagem` varchar(128) NOT NULL,PRIMARY KEY (`id`)) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;", false);
    return 1;
}

public OnFilterScriptExit() {
    print("Sistema de mensagens privadas: DESCARREGADO");
    mysql_close(con_mysql);
    return 1;
}

public OnPlayerConnect(playerid)
{
    new Cache:n, str[128], Nome[24];
    GetPlayerName(playerid, Nome, 24);
    mysql_format(con_mysql, str, sizeof(str), "SELECT id,novas_mensagens,email FROM mp_contas WHERE user='%s' LIMIT 1", Nome);
    n = mysql_query(con_mysql, str, true);
    if(cache_num_rows(con_mysql) > 0) {
        pData[playerid][mID] = cache_get_field_content_int(0, "id", con_mysql);
        pData[playerid][NovasMsg] = cache_get_field_content_int(0, "novas_mensagens", con_mysql);
        cache_get_field_content(0, "email", pData[playerid][Email], con_mysql, 128);
        if(pData[playerid][NovasMsg] > 0) {
            format(str, sizeof(str), "** Você tem %i novas mensagens privadas",pData[playerid][NovasMsg]);
            SendClientMessage(playerid,-1,str);
        }
    } else {
        new Cache:rn;
        mysql_format(con_mysql, str, sizeof(str), "INSERT INTO mp_contas (user) VALUES ('%s')", Nome);
        rn = mysql_query(con_mysql, str, true);
        pData[playerid][mID] = cache_insert_id(con_mysql);
        cache_delete(rn, con_mysql);
    }
    cache_delete(n, con_mysql);
    pData[playerid][Bloqueado] = false;
	return 1;
}


public OnPlayerDisconnect(playerid, reason)
{
    for(new pInf:i; i < pInf; i++)
        pData[playerid][i] = 0;
	return 1;
}
// Dialogs
public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    switch(dialogid) {
        case DialogOpMsg: {
            if(!response) return 1;
            switch(listitem) {
                case 0: { // Recebidas
                    pData[playerid][pagList] = 0;
                    carregar_MsgRecebidas(playerid, false);
                }
                case 1: { // Enviadas
                    pData[playerid][pagList] = 0;
                    carregar_MsgEnviadas(playerid);
                }
                case 2: { // Não lidas
                    pData[playerid][pagList] = 0;
                    carregar_MsgRecebidas(playerid, true);
                }
                case 3: { // Definir ou Alterar e-mail
                    new str[256],Em[128];
                    if(strlen(pData[playerid][Email]) > 0 && strfind(pData[playerid][Email], "@", true) != -1)
                        format(Em, 128, pData[playerid][Email]);
                    else
                        format(Em, 128, "Nenhum");
                    format(str,sizeof(str), "E-mail atual: %s\nInsira abaixo o e-mail desejado para notificações de novas mensagens:", Em);
                    ShowPlayerDialog(playerid, DialogDefinirEmail, DIALOG_STYLE_INPUT, "{FF0000}# {FFFFFF}Notificações por e-mail:", str, "Ok", "Cancelar");
                }
            }
            return 1;
        }
        case DialogDefinirEmail: {
            if(!response || strlen(inputtext) == 0) return cmd_minhasmp(playerid, "");
            new Msg[144], Query[220];
            format(pData[playerid][Email], 128, inputtext);
            format(Msg, 144, "{FFFF00}** E-mail definido para: {FFFFFF}%s{FFFF00}.", inputtext);
            SendClientMessage(playerid, -1, Msg);

            // Query
            mysql_format(con_mysql, Query, sizeof(Query), "UPDATE mp_contas SET email='%e' WHERE id=%i", inputtext, pData[playerid][mID]);
            mysql_query(con_mysql, Query, false);
            return 1;
        }
        case DialogMsgEnviada: {
            if(!response) return cmd_minhasmp(playerid,"");
            if(listitem >= 21) return pData[playerid][pagList] += 20, carregar_MsgEnviadas(playerid);
            new query[220], Cache:info, Dialog[180], Nome[24], Mensagem[128], Data[20];
            mysql_format(con_mysql, query, sizeof(query), "SELECT `mp_msgs`.*,`mp_contas`.`user` FROM `mp_msgs` INNER JOIN `mp_contas` ON `mp_msgs`.`para_contaid` = `mp_contas`.`id` WHERE `mp_msgs`.`de_contaid` = %i ORDER BY `mp_msgs`.`id` DESC LIMIT %i,20",pData[playerid][mID], pData[playerid][pagList]);
            info = mysql_query(con_mysql, query, true);
            if(cache_num_rows(con_mysql) > 0 && listitem < cache_num_rows(con_mysql)) {
                cache_get_field_content(listitem, "Mensagem", Mensagem, con_mysql);
                cache_get_field_content(listitem, "user", Nome, con_mysql, 24);
                cache_get_field_content(listitem, "data", Data, con_mysql, 20);
                format(Dialog, sizeof(Dialog), "Mensagem enviada para %s em %s\nMensagem: %s", Nome, Data, Mensagem);
                ShowPlayerDialog(playerid, DialogMsgRetorno, DIALOG_STYLE_MSGBOX, "{FFFF00}# {FFFFFF}Visualizando mensagem enviada:", Dialog, "Ok", "");
            }
            else SendClientMessage(playerid, -1, "{FF0000}Ocorreu um erro!");
            cache_delete(info, con_mysql);
            return 1;
        }
        case DialogMsgRecebida: {
            if(!response) return cmd_minhasmp(playerid, "");
            if(listitem >= 21) return pData[playerid][pagList] += 20, carregar_MsgRecebidas(playerid, false);
            new query[220], Cache:info, Dialog[180], Nome[24], Mensagem[128], Data[20];
            mysql_format(con_mysql, query, sizeof(query), "SELECT `mp_msgs`.*,`mp_contas`.`user` FROM `mp_msgs` INNER JOIN `mp_contas` ON `mp_msgs`.`de_contaid` = `mp_contas`.`id` WHERE `mp_msgs`.`para_contaid` = %i ORDER BY `mp_msgs`.`id` DESC LIMIT %i,20",pData[playerid][mID], pData[playerid][pagList]);
            info = mysql_query(con_mysql, query, true);
            if(cache_num_rows(con_mysql) > 0 && listitem < cache_num_rows(con_mysql)) {
                cache_get_field_content(listitem, "Mensagem", Mensagem, con_mysql);
                cache_get_field_content(listitem, "user", Nome, con_mysql, 24);
                cache_get_field_content(listitem, "data", Data, con_mysql, 20);
                format(Dialog, sizeof(Dialog), "Mensagem recebida de %s em %s\nMensagem: %s", Nome, Data, Mensagem);
                ShowPlayerDialog(playerid, DialogMsgRetorno, DIALOG_STYLE_MSGBOX, "{FFFF00}# {FFFFFF}Visualizando mensagem recebida:", Dialog, "Ok", "");
                if(cache_get_field_content_int(listitem, "lida", con_mysql) == 0) {
                    mysql_format(con_mysql, query, sizeof(query), "UPDATE mp_msgs SET lida=1 WHERE id=%i", cache_get_field_content_int(listitem, "id", con_mysql));
                    mysql_query(con_mysql, query, false);
                    if(pData[playerid][NovasMsg] > 0) {
                        pData[playerid][NovasMsg] -= 1;
                        mysql_format(con_mysql, query, sizeof(query), "UPDATE mp_contas SET novas_mensagens=%i WHERE id=%i",pData[playerid][NovasMsg], pData[playerid][mID]);
                        mysql_query(con_mysql, query, false);
                    }
                }
            }
            else SendClientMessage(playerid, -1, "{FF0000}Ocorreu um erro!");
            cache_delete(info, con_mysql);
            return 1;
        }
        case DialogMsgNaoLidas: {
            if(!response) return cmd_minhasmp(playerid, "");
            if(listitem >= 21) return pData[playerid][pagList] += 20, carregar_MsgRecebidas(playerid, true);
            new query[250], Cache:info, Dialog[180], Nome[24], Mensagem[128], Data[20];
            mysql_format(con_mysql, query, sizeof(query), "SELECT `mp_msgs`.*,`mp_contas`.`user` FROM `mp_msgs` INNER JOIN `mp_contas` ON `mp_msgs`.`de_contaid` = `mp_contas`.`id` WHERE `mp_msgs`.`para_contaid` = %i AND `mp_msgs`.`lida`=0 ORDER BY `mp_msgs`.`id` DESC LIMIT %i,20",pData[playerid][mID], pData[playerid][pagList]);
            info = mysql_query(con_mysql, query, true);
            if(cache_num_rows(con_mysql) > 0 && listitem < cache_num_rows(con_mysql)) {
                cache_get_field_content(listitem, "Mensagem", Mensagem, con_mysql);
                cache_get_field_content(listitem, "user", Nome, con_mysql, 24);
                cache_get_field_content(listitem, "data", Data, con_mysql, 20);
                format(Dialog, sizeof(Dialog), "Mensagem recebida de %s em %s\nMensagem: %s", Nome, Data, Mensagem);
                ShowPlayerDialog(playerid, DialogMsgRetorno, DIALOG_STYLE_MSGBOX, "{FFFF00}# {FFFFFF}Visualizando mensagem recebida:", Dialog, "Ok", "");
                if(cache_get_field_content_int(listitem, "lida", con_mysql) == 0) {
                    mysql_format(con_mysql, query, sizeof(query), "UPDATE mp_msgs SET lida=1 WHERE id=%i", cache_get_field_content_int(listitem, "id", con_mysql));
                    mysql_query(con_mysql, query, false);
                    if(pData[playerid][NovasMsg] > 0) {
                        pData[playerid][NovasMsg] -= 1;
                        mysql_format(con_mysql, query, sizeof(query), "UPDATE mp_contas SET novas_mensagens=%i WHERE id=%i",pData[playerid][NovasMsg], pData[playerid][mID]);
                        mysql_query(con_mysql, query, false);
                    }
                }
            }
            else SendClientMessage(playerid, -1, "{FF0000}Ocorreu um erro!");
            cache_delete(info, con_mysql);
            return 1;
        }
        case DialogMsgRetorno:  return cmd_minhasmp(playerid, "");

    }
	return 0;
}
// Stocks
forward HTTP_Resposta(index, response_code, data[]);
stock enviarEmail(de[], para[], titulo[], mensagem[]) {
    new str[512]; // de (128) + para (128) + titulo (128) + mensagem (128) ..
    format(str, sizeof(str), "de=%s&para=%s&titulo=%s&msg=%s", de, para, titulo, mensagem);
    http_request++;
    return HTTP(http_request, HTTP_POST, URL_EMAIL, str, "HTTP_Resposta");
}
public HTTP_Resposta(index, response_code, data[]) {
    return printf("HTTP: %i %i %s", index, response_code, data);
}

carregar_MsgRecebidas(playerid, bool:apenasnaolidas = false) {
    new str[250], Cache:re;
    mysql_format(con_mysql, str, sizeof(str), "SELECT `mp_msgs`.`Mensagem`,`mp_contas`.`user` FROM `mp_msgs` INNER JOIN `mp_contas` ON `mp_msgs`.`de_contaid` = `mp_contas`.`id` WHERE `mp_msgs`.`para_contaid` = %i %s ORDER BY `mp_msgs`.`id` DESC LIMIT %i,20", pData[playerid][mID], (apenasnaolidas == true) ? ("AND `mp_msgs`.`lida`=0") : (""), pData[playerid][pagList]);
    re = mysql_query(con_mysql, str, true);
    if(cache_num_rows(con_mysql) > 0) { // Se há mensagens
        new Nome[24], Mensagem[64], Dialog[1500];
        for(new i; i < cache_num_rows(con_mysql); i++) {
            cache_get_field_content(i, "user", Nome, con_mysql, 24);
            cache_get_field_content(i, "Mensagem", Mensagem, con_mysql, 64);
            format(Dialog, sizeof(Dialog), "%s%s: %s%s\r\n",Dialog,Nome,Mensagem,(strlen(Mensagem) >= 63) ? ("...") : (""));
        }
        if(cache_num_rows(con_mysql) >= 20)
            strcat(Dialog, "\r\n{FFFF00}Próxima Página");
        ShowPlayerDialog(playerid, (apenasnaolidas == false) ? (DialogMsgRecebida) : (DialogMsgNaoLidas), DIALOG_STYLE_LIST, "{FF0000}# {FFFFFF}Mensagens recebidas", Dialog, "Selecionar", "Cancelar");
    } else SendClientMessage(playerid, -1, "{FF0000}[MP] Não há mensagens!");
    cache_delete(re, con_mysql);
    return 1;
}
carregar_MsgEnviadas(playerid) {
    new str[250], Cache:en;
    mysql_format(con_mysql, str, sizeof(str), "SELECT `mp_msgs`.`Mensagem`,`mp_contas`.`user` FROM `mp_msgs` INNER JOIN `mp_contas` ON `mp_msgs`.`para_contaid` = `mp_contas`.`id` WHERE `mp_msgs`.`de_contaid` = %i ORDER BY `mp_msgs`.`id` DESC LIMIT %i,20", pData[playerid][mID], pData[playerid][pagList]);
    en = mysql_query(con_mysql, str, true);
    if(cache_num_rows(con_mysql) > 0) {
        new Nome[24], Mensagem[64], Dialog[1500];
        for(new i; i < cache_num_rows(con_mysql); i++) {
            cache_get_field_content(i, "user", Nome, con_mysql, 24);
            cache_get_field_content(i, "Mensagem", Mensagem, con_mysql, 64);
            format(Dialog, sizeof(Dialog), "%s%s: %s%s\r\n", Dialog,Nome,Mensagem,(strlen(Mensagem) >= 63) ? ("...") : (""));
        }
        if(cache_num_rows(con_mysql) >= 20)
            strcat(Dialog, "\r\n{FFFF00}Próxima Página");
        ShowPlayerDialog(playerid, DialogMsgEnviada, DIALOG_STYLE_LIST, "{FF0000}# {FFFFFF}Mensagens enviadas", Dialog, "Selecionar", "Cancelar");
    }
    else SendClientMessage(playerid, -1, "{FF0000}[MP] Não há mensagens!");
    cache_delete(en, con_mysql);
    return 1;
}

// Comandos
CMD:mp(playerid, params[]) {
    new Msg[144], id, Mensagem[128];
    if(pData[playerid][Bloqueado] != false) return SendClientMessage(playerid, -1, "{FF0000}Você bloqueou as mensagens privadas.");
    if(sscanf(params, "us[128]", id, Mensagem)) return SendClientMessage(playerid, -1, "{FF0000}* Use: /mp [id/nome] [mensagem]");
    if(playerid == id) return SendClientMessage(playerid, -1, "{FF0000}Você não pode enviar mensagem para si mesmo.");
    if(strlen(Mensagem) >= 127) return SendClientMessage(playerid, -1, "{FF0000}Mensagem grande demais!");
    if(!IsPlayerConnected(id)) { // Caso o jogador não esteja 'online', ele irá receber a mensagem assim que se conectar
        new Nome[24], Cache:ec, q1[250], Data[6];
        sscanf(params, "s[24]s[128]", Nome, Mensagem);
        getdate(Data[2], Data[1], Data[0]);
        gettime(Data[3], Data[4], Data[5]);
        mysql_format(con_mysql, q1, sizeof(q1), "SELECT id,novas_mensagens,email FROM mp_contas WHERE user='%e' LIMIT 1", Nome);
        ec = mysql_query(con_mysql, q1, true);
        if(cache_num_rows(con_mysql) > 0) {
            new pid = cache_get_field_content_int(0, "id", con_mysql), novas = cache_get_field_content_int(0, "novas_mensagens", con_mysql), pEmail[128];
            cache_get_field_content(0, "email", pEmail, con_mysql, 128);
            mysql_format(con_mysql, q1, sizeof(q1), "INSERT INTO mp_msgs (de_contaid,para_contaid,Mensagem,lida,horario,data) VALUES (%i,%i,'%e',0,%i,'%02d/%02d/%d %02d:%02d')", pData[playerid][mID], pid, Mensagem, gettime(), Data[0], Data[1], Data[2], Data[3], Data[4]);
            mysql_query(con_mysql, q1, false);
            mysql_format(con_mysql, q1, sizeof(q1), "UPDATE mp_contas SET novas_mensagens=%i WHERE id=%i", novas+1, pid);
            mysql_query(con_mysql, q1, false);
            format(Msg, sizeof(Msg), "{FFFF00}[MP ENVIADO] %s: %s",Nome,Mensagem);
            SendClientMessage(playerid, -1, Msg);
            if(strlen(pEmail) > 0 && strfind(pEmail, "@", true) != -1) {
                new MeuNome[24], MsgEmail[200];
                GetPlayerName(playerid, MeuNome, 24);
                format(MsgEmail, sizeof(MsgEmail), "Olá %s,\r\nVocê recebeu uma mensagem de %s no servidor.\r\nMensagem: %s",Nome, MeuNome, Mensagem);
                enviarEmail(EMAIL_ENVIO, pEmail, "Nova mensagem privada", MsgEmail);
            }
        }
        else SendClientMessage(playerid,-1, "{FF0000}Ocorreu um erro ao enviar uma mensagem privada a este jogador.");
        cache_delete(ec, con_mysql);
        return 1;
    }
    if(pData[id][Bloqueado] != false) return SendClientMessage(playerid, -1, "{FF0000}Este jogador desabilitou o recebimento de mensagens privadas!");
    new MyNome[24], OtNome[24];
    GetPlayerName(playerid, MyNome, 24);
    GetPlayerName(id, OtNome, 24);
    format(Msg, 144, "{FFFF00}*[MP RECEBIDO] %s [%i]: %s", MyNome, playerid, Mensagem);
    SendClientMessage(id, -1, Msg);
    format(Msg, 144, "{FFFF00}*[MP ENVIADO] %s [%i]: %s", OtNome, id, Mensagem);
    SendClientMessage(playerid, -1, Msg);
    // Efetuar Query
    new query[200], Data[6];
    getdate(Data[2], Data[1], Data[0]);
    gettime(Data[3], Data[4], Data[5]);
    mysql_format(con_mysql, query, sizeof(query), "INSERT INTO mp_msgs (de_contaid,para_contaid,Mensagem,lida,horario,data) VALUES (%i,%i,'%e',1,%i,'%02d/%02d/%d %02d:%02d')", pData[playerid][mID], pData[id][mID], Mensagem, gettime(), Data[0], Data[1], Data[2], Data[3], Data[4]);
    mysql_query(con_mysql, query, false);
    return 1;
}
CMD:minhasmp(playerid, params[]) return ShowPlayerDialog(playerid, DialogOpMsg, DIALOG_STYLE_LIST, "{FFFF00}# {FFFFFF}Mensagens privadas:", "Recebidas\r\nEnviadas\r\nApenas não lidas\r\nE-mail para notificações", "Selecionar", "Cancelar");
CMD:ativarmp(playerid, params[]) {
    if(pData[playerid][Bloqueado] == false) return SendClientMessage(playerid, -1, "{FF0000}As mensagens privadas já estão ativadas!");
    pData[playerid][Bloqueado] = false;
    SendClientMessage(playerid, -1, "{FFFF00}Mensagens privadas ativadas!");
    return 1;
}
CMD:desativarmp(playerid, params[]) {
    if(pData[playerid][Bloqueado] != false) return SendClientMessage(playerid, -1, "{FF0000}As mensagens privadas já estão desativadas!");
    pData[playerid][Bloqueado] = true;
    SendClientMessage(playerid, -1, "{FFFF00}Mensagens privadas desativadas!");
    return 1;
}
CMD:mps(playerid, params[]) return (pData[playerid][Bloqueado] == false) ? (cmd_desativarmp(playerid, params)) : (cmd_ativarmp(playerid, params));

/*
        www.brasilmegatrucker.com
    Sistema criado por Nícolas Corrêa
*/
