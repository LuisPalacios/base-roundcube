<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html lang="es">
<head>
<meta name="robots" content="noindex, nofollow">
<title>Error 404</title>
</head>
<body  bgcolor="silver">
<center>
 <br>
 <hr width=60%>
 <h1>No he encontrado la p&aacute;gina</h2>
 <p>Lo siento pero la p&aacute;gina que buscas no existe.</p>
 <a href="/">Ir a la p&aacute;gina principal</a>
 <hr width=60%>
</center>

<?php
# custom thing...

# return allways 404
http_response_code(404);
?>
