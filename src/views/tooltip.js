


<script type="text/javascript" >
     ;

// tooltip の生成と破壊
$(".item").on({
        'mouseenter':function(){
            var text = $(this).attr('data-text');
            $(this).parent().append('<div class="tooltip tooltipL">'+text+'</div>');
            $('.tooltip').hide();
        },
        'mouseleave':function(){
            $(this).parent().find(".tooltip").remove();
        }
});

// イベントの間引き
function delayedExe(job, time) {
    if( job in delayedExe.TID) {
        window.clearTimeout(delayedExe.TID[job]);
    }
    delayedExe.TID[job] = window.setTimeout(
        function() {
            delete delayedExe.TID[job];
            try {
                job.call();
            } catch(e) {
                alert("EXCEPTION CAUGHT : " + job);
            }
        }, time);
}
delayedExe.TID = {};

// マウスの移動に伴う tooltip の移動
$('.item').mousemove(function(e){
        delayedExe( function() {
                var windowWidth = window.innerWidth ;
                var tipsize = $('.tooltip').width();
                var top  = e.pageY + 15 ;
                var left = e.pageX + 5 ;
                var x    = e.clientX;
        
                if ( ( windowWidth / 2  ) < x ) {
                    left = left - tipsize - 15 ;
                    $('.tooltip').removeClass('tooltipL');
                    $('.tooltip').addClass('tooltipR');
                } else {
                    $('.tooltip').removeClass('tooltipR');
                    $('.tooltip').addClass('tooltipL');
                }
                
                $('.tooltip').css({
                        'top':  top,
                        'left': left
                });
                $('.tooltip').show();
            },100);
    });

</script>

<style type="text/css">

    /* 吹き出し */
.tooltip {
  position: absolute;
  margin: -1em,-1em;
  width: max-content;
  z-index: 9999;
  padding: 0.3em 0.5em;
  color: #FFFFFF;
  background: dimgray;
  border-radius: 0.5em;
  text-align: center;
}

/* 左 吹き出しぐちの三角   */
.tooltipL:after {
  content: "";
  display: block;
  position: absolute;
  left: 0.5em;
  top: -8px;
  border-top:8px solid transparent;
  border-left:8px solid dimgray;
}

/* 右 吹き出しぐちの三角   */
.tooltipR:after {
  content: "";
  display: block;
  position: absolute;
  right: 0.5em;
  top: -8px;
  border-top:8px solid transparent;
  border-right:8px solid dimgray;
}


</style>
