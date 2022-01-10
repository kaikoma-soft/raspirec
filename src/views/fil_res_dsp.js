
<script type="text/javascript" >

    $(".item").click(function(event){
        var fa_flag = $("#title").attr('fa_flag');
        //console.log( fa_flag );
        if ( fa_flag == 1) return false    // フィルターの場合のみ

        var proid = $(this).attr('rid');
        //console.log( proid );
        //event.preventDefault();
        $("#sample-dialog").load('/prg_dialog/' + proid );
        $("#sample-dialog").dialog({
             modal: true,
             maxWidth: 1200,
             width:    1000,
             buttons: { //ボタン
               "録画予約": function() {
                   $.ajax({
                      url:    '/rsv_conf',
                      type:   "POST",
                      async:  true,
                      timeout: 30000
                    }).done( function(data) {
                        //console.log( data );
                        $("#sample-dialog2").html(data);
                    })
                    confirmDialog( proid );
               },
               "自動予約": function() {
                   $(this).dialog("close");
                   //window.location.href = "/aut_rsv_ins/" + proid;
                   window.location.href = "/search/pro/" + proid;
               },
               "閉じる": function() {
                   $(this).dialog("close");
               }
             },
             open: function() {
               $( this ).siblings('.ui-dialog-buttonpane').find('button:eq(2)').focus();
             }
           });
        return false;
    });

 
    // フィルター以外の場合に、修正・削除ダイアログ
    $(".item").click(function(event){
        var fa_flag = $("#title").attr('fa_flag');
        //console.log( fa_flag );
        if ( fa_flag == 0) return false

        var resid = $(this).attr('resid');
        console.log( resid );
        //event.preventDefault();
        $("#sample-dialog").load('/rsv_list_D/' + resid );
        $("#sample-dialog").dialog({
             modal: true,
             maxWidth: 1200,
             width:    1000,
             buttons: { //ボタン
               "修正": function() {
                   $.ajax({
                       url: '/rsv_list/Mod/' + resid,
                       type:"POST",
                       data:  $('form').serialize() + '&param=1',
                       async: true,
                       timeout: 30000
                   }).done( function(results) {
                       location.reload();
                   })
               },
               "削除": function() {
                   $.ajax({
                       url: '/rsv_list/Del/' + resid,
                       type:"POST",
                       async: true,
                       timeout: 30000
                   }).done( function(results) {
                       location.reload();
                   })
               },
               "閉じる": function() {
                   $(this).dialog("close");
               }
             },
             open: function() {
               $( this ).siblings('.ui-dialog-buttonpane').find('button:eq(2)').focus();
             }
           });
        return false;
    });

    function confirmDialog( proid ) {
      $("#sample-dialog2").dialog({
        modal: true,
        maxWidth: 1200,
        width:    800,
        buttons: { //ボタン
          "登録": function() {
            $('<input>').attr({
                'type': 'hidden',
                'name': 'proid',
                'value': proid
            }).appendTo('#form');

            $('#form').submit();
          },
          "閉じる": function() {
            $(this).dialog("close");
            }
          },
        open: function() {
          $( this ).siblings('.ui-dialog-buttonpane').find('button:eq(2)').focus();
        }
      });
      return false;
    };
    
</script>
