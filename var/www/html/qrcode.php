<html lang="pt-BR">
<head>
  <title>Myzap Web 2.0</title>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="format-detection" content="telephone=no" />
  <link rel="stylesheet" id="style" href="qrcode.css" />
</head>
<body>
   
  <?php
    function executaSQL($sql){
      try {
        $conexao = new PDO ("firebird:dbname=192.168.20.30/10108:C:\\SCI\\Arquivos\\Database\\000509.FDB", "SYSDBA", "masterkey");
        return $conexao->query($sql)->fetchAll();
      } catch (Exception $e){
        echo 'Erro'.$e->getMessage();
      }
    } 

    $id = isset($_GET['id']) ? $_GET['id'] : ''; 
    
    if($id <> ''){
      $sql = "select * from controlealteracoes c where c.identificador = '".$id."'";
      $dados = executaSQL($sql);
      
      if(count($dados) > 0){
        $valores = json_decode($dados[0]['VALOR']);
        foreach ($valores as $chave => $valor){
          echo "<input type='hidden' id='$chave' name='$chave' value='$valor' />"; 
        }
      }else{
        echo 'Id não localizado';
      }
    }
    else
      echo 'Parâmetro id não informado';
  ?>
  
  <div id="app">
    <div class="app-wrapper app-wrapper-web">
      <div id="wrapper">
        <div id="window">

          <div class="entry-main">
            <div class="qrcode">
              <img alt="Leia o QRCODE" id="base64" style="display: block;" src="qr-start.png" />
            </div>

            <div class="entry-text" style="text-align: center;">
              <div class="entry-title">Terasoft</div>
              <div class="entry-subtitle">Use o WhatsApp no seu telefone para ler o qrcode</div>

              <div class="entry-controls">
                <label> <button type="button" id="buttonStart" class="btn btn-primary"> Conectar nova sessão</button>
                </label>
                <div class="hint" id="idSessao">Sessão: </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    </div>

  </div>
</body>

</html>

<script src="https://code.jquery.com/jquery-3.6.0.min.js" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/gasparesganga-jquery-loading-overlay@2.1.7/dist/loadingoverlay.min.js"
  crossorigin="anonymous"></script>
<script src="https://cdn.socket.io/4.3.2/socket.io.min.js"
  integrity="sha384-KAZ4DtjNhLChOB/hxXuKqhMLYvx3b5MlT55xPEiNmREKRzeEm+RVPlTnAn0ajQNs" crossorigin="anonymous"></script>

<script>
 // console.log('teste');

  $(document).ready(function(){
    
    var servidor   = $('#server').val();
    var apitoken   = $('#apitoken').val();
    var session    = $('#session').val();
    var sessionkey = $('#sessionkey').val();
    var wh_connect = $('#wh_connect').val();
    var wh_message = $('#wh_message').val();
    var wh_status  = $('#wh_status').val();
    var wh_qrcode  = $('#wh_qrcode').val();  
    var autostart  = $('#autostart').val(); 
    var timeoutlogout  = $('#timeout').val();
        
    try {
      socket = io(servidor, {
        withCredentials: false,
      });

    } catch (error) {
      console.log('API Desconectada!!! cd /opt/MyZap2.x.x.x node start index.js');
    }
    
    $('#buttonStart').on('click', function() {
      requestMyZap(servidor, apitoken, sessionkey, session, wh_connect, wh_message, wh_status, wh_qrcode, timeoutlogout, 'start');
    })

    function requestMyZap(servidor, apitoken, sessionkey, session, wh_connect, wh_message, wh_status, wh_qrcode, timeoutlogout, action) {

      var URL = servidor+'/'+action;

      socket.on('whatsapp-status', function(status) {
        try {
          console.log(status)
        } catch (error) {
          console.log('API Desconectada!!! cd /opt/MyZap2.x.x.x node start index.js')
        }
      })

      socket.on('qrCode', function(qrCode) {
        console.log(qrCode);
        if (qrCode.session == session) {
          $('#base64').attr('src', qrCode.data);
          $('#base64').LoadingOverlay("hide");
          $('#buttonStart').attr('disabled', true);
          $('#idSessao').html('Sessão: '+session);
        }
      })

      switch (action) {
        case 'start':
          $.post({
            url: URL,
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'apitoken': apitoken || '', 'sessionkey': sessionkey || ''},
            data: JSON.stringify({
              session: session || '',
              wh_connect: wh_connect || '',
              wh_message: wh_message || '',
              wh_status: wh_status || '',
              wh_qrcode: wh_qrcode || '',
	      timeout: timeoutlogout,
            }),
            beforeSend: function (data, xhr) {
              $('#base64').LoadingOverlay("show")
            },
            success: function (data) {

              $('#buttonStart').attr('disabled', false)
              $('#base64').LoadingOverlay("hide")

            },
            error: function (error) {
              $('#base64').LoadingOverlay("hide")
            },
          })
          break;

        default:
          console.log('requisição inválida.')
          break;
      }

    }

    if (autostart == '1') {
    	$('#buttonStart').click();
    }

  });

</script>