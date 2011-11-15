Canvas = require 'canvas'
fs     = require 'fs'
path   = require 'path'

sourceFile = process.argv.slice(-1)[0]

# load image file
img = new Canvas.Image
img.src = fs.readFileSync sourceFile

# render to canvas
stage = new Canvas img.width, img.height
ctx = stage.getContext '2d'

ctx.drawImage img, 0, 0, img.width, img.height

imgData = ctx.getImageData(0, 0, img.width, img.height)
pixels = imgData.data

# 640 x 59
tileWidth = 32
n_tiles = Math.ceil img.width/32

# start comparisons for every tile
compare = (reverse) ->
    matches = {}
    matchDiffs = {}
    matchedTiles = []
    for tile_A in [1..img.width/tileWidth]
    
        # edges of tile A
        if reverse
            edge_A = (tile_A-1) * tileWidth * 4
        else
            edge_A = tile_A * tileWidth * 4 - 4
    
        # store the difference between edges of tiles
        compared = {}
    
        # compare this to every other column
        for tile_B in [1..img.width/tileWidth] when tile_B != tile_A
        
            # left edge of tile B
            if reverse
                edge_B = tile_B * tileWidth * 4 - 4
            else
                edge_B = (tile_B-1) * tileWidth * 4
                
            diff = 0
        
            for line in [0..img.height]
            
                # position in rgb array for each pixel of column
                i_A = line * img.width * 4 + edge_A
                i_B = line * img.width * 4 + edge_B
            
                # calculate difference between adjacent pixels
                R_diff   = Math.abs(pixels[i_A+0] - pixels[i_B+0]) / 255
                G_diff   = Math.abs(pixels[i_A+1] - pixels[i_B+1]) / 255
                B_diff   = Math.abs(pixels[i_A+2] - pixels[i_B+2]) / 255
                diff += ((R_diff + G_diff + B_diff) * 3) or 0
        
            compared[tile_B] = diff
    
        lastDiff = Infinity
        match = 0
        for i, diff of compared
            if diff < lastDiff and i not in matchedTiles
                match = i
                lastDiff = diff
    
        matches[tile_A] = match
        matchedTiles.push match
    
        matchDiffs[tile_A] = [match, lastDiff]
    
    return {
        matches: matches
        diffs: matchDiffs
    }

matches = compare().matches
next = n_tiles
order = [n_tiles]
order.push next while (next = matches[next]) not in order
order.pop()

matches = compare(true).matches
next = n_tiles
order2 = []
order2.unshift next while (next = matches[next]) not in order2

# find wrapping point
pos = n_tiles
while order[pos] == order2[pos]
    pos--

# cut it
Array::push.apply order, order.splice(0, pos)

# re-order tiles
for tile, pos in order
    # source
    [sx, sy] = [(tile-1) * tileWidth, 0]
    [sw, sh] = [tileWidth, img.height]
    # destination
    [dx, dy] = [pos * tileWidth, 0]
    console.log "#{tile} -> #{pos}"
    ctx.drawImage img, sx, sy, sw, sh, dx, dy, sw, sh

# save to file
ext = path.extname sourceFile
newFile = "#{path.basename sourceFile, ext}_untiled#{ext}"
out = fs.createWriteStream "#{__dirname}/#{newFile}"
stream = stage.createPNGStream()

stream.on 'data', (chunk) -> out.write chunk
stream.on 'end', -> console.log "Saved to #{newFile}"
