<?php
	if(!isset($_POST['msg']) || !isset($_POST['para']) || !isset($_POST['titulo']) || !isset($_POST['de']))
		die ('Erro.');
	
	$mensagem = utf8_encode($_POST['msg']);
	$para = $_POST['para'];
	$titulo = utf8_encode($_POST['titulo']);
	$de = $_POST['de'];
	
	$headers = "MIME-Version: 1.1\r\n";
	$headers .= "Content-type: text/plain; charset=utf8\r\n";
	$headers .= "From: $de\r\n"; // remetente
	$headers .= "Return-Path: $de\r\n"; // return-path
	$enviar = mail($para, $titulo, $mensagem, $headers);
	if($enviar) echo 'E-mail enviado!';
	else echo 'Ocorreu um erro e o e-mail não pode ser enviado!';
?>
