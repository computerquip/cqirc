%x PREFIX
%x PREFIX_END
%x PREFIX_OPT
%x PREFIX_HOST
%x PREFIX_USER
%x PARAMS
%x PARAM
%x TRAILING
%x END

%option reentrant
%option case-insensitive
%option noyywrap
%option extra-type="struct cq_irc_proxy *"

special		[\x5B-\x60\x7B-\x7D]
hostchar	("_"|"/"|[[:alnum:]])

user 		[^\0\r\n\x20\@]+
nickname	([[:alpha:]]|{special})([[:alnum:]]|{special}|"-")*{0,8}
shortname	[[:alnum:]]([[:alnum:]]|"-")*[[:alnum:]]*
host 		{hostchar}({hostchar}|"-"|"."|":")*
hostname	{shortname}(\.{shortname})*
servername	{hostname}
middle		[^\:\0\r\n\ ][^\ \0\r\n]*
crlf 		(\r\n|\n\r)

%{
	#include "irc-proxy.h"
	#include <assert.h>
%}

%%

<INITIAL>{
	":"					BEGIN(PREFIX);
	"PING"				BEGIN(PARAMS); yyextra->signal = signal_ping_proxy;
	"PONG"				BEGIN(PARAMS); yyextra->signal = signal_pong_proxy;
	"QUIT"  			BEGIN(PARAMS); yyextra->signal = signal_quit_proxy;
	"PRIVMSG"			BEGIN(PARAMS); yyextra->signal = signal_privmsg_proxy;
	"NOTICE"			BEGIN(PARAMS); yyextra->signal = signal_notice_proxy;
	"ERROR"				BEGIN(PARAMS); yyextra->signal = signal_error_proxy;
	.					return -1; /* Unknown Command */
}

<PREFIX>{
	{nickname} 			BEGIN(PREFIX_OPT); yyextra->message->prefix.source = strndup(yytext, yyleng);
	{servername}		BEGIN(PREFIX_END); yyextra->message->prefix.source = strndup(yytext, yyleng); 
}

<PREFIX_END>{
	" " 				BEGIN(INITIAL);
}

<PREFIX_OPT>{
	"!"					BEGIN(PREFIX_USER);
	"@"					BEGIN(PREFIX_HOST);
	" "					BEGIN(INITIAL);
}

<PREFIX_USER>{user} 	BEGIN(PREFIX_OPT); yyextra->message->prefix.user = strndup(yytext, yyleng);
<PREFIX_HOST>{host} 	BEGIN(PREFIX_OPT); yyextra->message->prefix.host = strndup(yytext, yyleng);

<PARAMS>{
	" "					BEGIN(PARAM);
	{crlf}				BEGIN(END);
}

<END>{
	<<EOF>>				yyextra->signal(yyextra); return 0;
}

<PARAM>{
	":"					BEGIN(TRAILING);
	{middle}			BEGIN(PARAMS); yyextra->message->params.param[yyextra->message->params.length] = strndup(yytext, yyleng); ++yyextra->message->params.length;
}

<TRAILING>{
	[^\0\n\r]*			BEGIN(PARAMS); yyextra->message->trailing = strndup(yytext, yyleng);
}

<<EOF>>					return -2;  /* Not enough input */

%%