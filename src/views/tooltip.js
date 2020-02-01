


<script type="text/javascript" >

    $(".item").hover(function() {
        $(this).css('border','solid #a23456 1px');
    }, function() {
        $(this).css('border','');
    });

    $(document).ready(function(){
       $('.item').tooltip( );
    });

</script>
