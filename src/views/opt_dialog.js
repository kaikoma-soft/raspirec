
<script type="text/javascript" >

    $("#option").click(function(event){
        var proid = $(this).attr('pid');
        event.preventDefault();
        $("#option-dialog").load('/opt_dialog' );
        $("#option-dialog").dialog({
             modal: true,
             maxWidth: 1200,
             width:    1000,
             buttons: { //ボタン
               "保存": function() {
                 url = '/opt_dialog/save';
                 $.ajax({
                   url: url,
                   type:"POST",
                   data:  $('form').serialize() + '&param=1',
                   async: true,
                   timeout: 30000
                 }).done( function(results) {
                   location.reload();
                 }).fail(function (jqXHR, textStatus, errorThrown) {
                   console.log("ajax通信に失敗しました");
                   console.log("URL : " + url);
                   $("#sample-dialog1").html("<p>ajax通信に失敗しました");
                 })
               },
               "キャンセル": function() {
                   $(this).dialog("close");
               }
             },
             open: function() {
               $( this ).siblings('.ui-dialog-buttonpane').find('button:eq(1)').focus();
             }
           });
        return false;
    });

</script>
