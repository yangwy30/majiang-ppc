# Recreates app/MajiangApp/Support/ReferenceSheet.swift + TileFace.swift (PR #7) as HTML, rendered at 2x.
W=40; H=round(W*1.32); INS=W*0.14; IW=W-2*INS; IH=H-2*INS
FACE='#FFFDF8'; EDGE='#E2DDD0'; SHADOW='#D6D0C1'; BLUE='#23406B'; GREEN='#2F5D46'; RED='#C23B22'; INK='#16150F'
def el(x,y,w,h,style): return f'<div style="position:absolute;left:{x:.2f}px;top:{y:.2f}px;width:{w:.2f}px;height:{h:.2f}px;{style}"></div>'
def stick(cx,cy,w,h,red):
    c=RED if red else GREEN; band=max(1,h*0.07)
    return el(cx-w/2,cy-h/2,w,h,f'background:{c};border-radius:{w/2}px')+el(cx-w/2,cy-band/2,w,band,f'background:{FACE}')
def grid(xs,ys,red=lambda x,y:False): return [(x,y,red(x,y)) for y in ys for x in xs]
def bamboo(r):
    if r==1:
        d=IW*0.3; sw=IW*0.22; sh=IH*0.62; gap=IH*0.04; tot=d+gap+sh; y0=(IH-tot)/2
        return el(IW/2-d/2,y0,d,d,f'background:{RED};border-radius:50%')+stick(IW/2,y0+d+gap+sh/2,sw,sh,False)
    L={2:[(0.5,0.27,0),(0.5,0.73,0)],3:[(0.5,0.27,0),(0.28,0.73,0),(0.72,0.73,0)],4:grid([0.28,0.72],[0.27,0.73]),
       5:grid([0.2,0.8],[0.27,0.73])+[(0.5,0.5,1)],6:grid([0.2,0.5,0.8],[0.27,0.73]),
       7:[(0.5,0.15,1)]+grid([0.2,0.5,0.8],[0.5,0.84]),8:grid([0.14,0.38,0.62,0.86],[0.27,0.73]),
       9:grid([0.2,0.5,0.8],[0.15,0.5,0.85],lambda x,y:x==0.5)}[r]
    w=IW*(0.13 if r==8 else 0.15); h=IH*(0.26 if r>=7 else 0.36)
    return ''.join(stick(x*IW,y*IH,w,h,red) for x,y,red in L)
def dots(r):
    b,g,rd=BLUE,GREEN,RED
    S={1:[(0.5,0.5,rd,0.86)],2:[(0.5,0.26,g,0.46),(0.5,0.74,b,0.46)],3:[(0.2,0.16,b,0.38),(0.5,0.5,rd,0.38),(0.8,0.84,g,0.38)],
       4:[(0.26,0.27,b,0.44),(0.74,0.27,g,0.44),(0.26,0.73,g,0.44),(0.74,0.73,b,0.44)],
       5:[(0.22,0.2,b,0.38),(0.78,0.2,g,0.38),(0.5,0.5,rd,0.38),(0.22,0.8,g,0.38),(0.78,0.8,b,0.38)],
       6:[(0.27,0.16,g,0.38),(0.73,0.16,g,0.38),(0.27,0.5,rd,0.38),(0.73,0.5,rd,0.38),(0.27,0.84,rd,0.38),(0.73,0.84,rd,0.38)],
       7:[(0.18,0.1,g,0.3),(0.5,0.23,g,0.3),(0.82,0.36,g,0.3),(0.27,0.63,rd,0.34),(0.73,0.63,rd,0.34),(0.27,0.89,rd,0.34),(0.73,0.89,rd,0.34)],
       8:[(x,y,b,0.32) for y in [0.11,0.37,0.63,0.89] for x in [0.27,0.73]],
       9:[(x,y,c,0.3) for y,c in [(0.16,b),(0.5,rd),(0.84,g)] for x in [0.17,0.5,0.83]]}[r]
    out=''
    for x,y,c,s in S:
        s*=IW; lw=max(1,s*0.13); f=s*0.34
        out+=el(x*IW-s/2,y*IH-s/2,s,s,f'box-sizing:border-box;border:{lw:.2f}px solid {c};border-radius:50%')
        out+=el(x*IW-f/2,y*IH-f/2,f,f,f'background:{c};border-radius:50%')
    return out
NUM="一二三四五六七八九"; HON="东南西北中发白"
def text(t,size,color,weight):
    return f'<div style="font-size:{size}px;font-weight:{weight};color:{color};line-height:1">{t}</div>'
def chars(r):
    return f'<div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center">{text(NUM[r-1],W*0.42,INK,700)}{text("萬",W*0.44,RED,700)}</div>'
def honor(r):
    if r==7:
        p=W*0.06; lw=max(1.5,W*0.05)
        return el(p,p,IW-2*p,IH-2*p,f'box-sizing:border-box;border:{lw}px solid {BLUE};border-radius:{W*0.08}px')
    c=RED if r==5 else GREEN if r==6 else INK
    return f'<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">{text(HON[r-1],W*0.62,c,900)}</div>'
def tile(face):
    rad=W*0.16
    return (f'<div style="position:relative;width:{W}px;height:{H}px">'
      +el(0,1.5,W,H,f'background:{SHADOW};border-radius:{rad}px')
      +el(0,0,W,H,f'box-sizing:border-box;background:{FACE};border:1px solid {EDGE};border-radius:{rad}px')
      +f'<div style="position:absolute;left:{INS}px;top:{INS}px;width:{IW}px;height:{IH}px">{face}</div></div>')
rows=[[(chars(r),f'{r}m') for r in range(1,10)],[(bamboo(r),f'{r}s') for r in range(1,10)],
      [(dots(r),f'{r}p') for r in range(1,10)],[(honor(r),HON[r-1]) for r in range(1,8)]]
body=''.join('<div style="display:flex;gap:6px">'+''.join(
  f'<div style="display:flex;flex-direction:column;align-items:center;gap:2px">{tile(f)}<div style="font-size:11px;font-weight:500;color:#000">{n}</div></div>' for f,n in row)+'</div>' for row in rows)
html=f'<html><body style="margin:0;font-family:\'WenQuanYi Zen Hei\',sans-serif"><div id="s" style="display:inline-flex;flex-direction:column;gap:10px;padding:12px;background:#fff">{body}</div></body></html>'
open('sheet.html','w').write(html)
