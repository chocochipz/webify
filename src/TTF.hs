{-# LANGUAGE RecordWildCards #-}

module TTF(
  TTF(..)
  , OS2(..)
  , Head(..)
  , Hhea(..)
  , Name(..)
  , NameRecord(..)
  , TableDirectory(..)
  , Cmap(..)
  , CmapEncodingDirectory(..)
  , HMetric(..)
  , Hmtx(..)
  , Glyf(..)
  , CompositeGlyfElement(..)
  , CmapTable(..)
  , UFWord
  , UShort
  , ULong
  , Byte
  , parse
  , glyphId
  , cmapStart
  , cmapEnd
  , cmapTableFind
) where

import Control.Monad
import Data.Binary.Strict.Get
import Data.Bits
import qualified Data.ByteString as B
import Data.ByteString.Char8 (unpack)
import Data.Int
import Data.List
import Data.Map hiding(map, findIndex)
import Data.Maybe
import Data.Maybe (fromJust)
import qualified Data.Text as T
import Data.Text.Encoding
import Data.Text.Encoding.Error
import qualified Data.Vector as V
import Data.Word
import Utils

type Byte = Word8
type Char = Int8
type UShort = Word16
type Short = Int16
type FWord = Int16
type UFWord = Word16
type ULong = Word32
-- type Long = Int32
type Fixed = Word32


getFixed :: Get Fixed
getFixed = liftM fromIntegral getWord32be

getULong :: Get ULong
getULong = getWord32be

getUShort :: Get UShort
getUShort = getWord16be

getShort :: Get Short
getShort = liftM fromIntegral getWord16be

getByte :: Get Byte
getByte = getWord8

getChar :: Get TTF.Char
getChar = liftM fromIntegral getWord8

getFWord :: Get FWord
getFWord = getShort

getUFWord :: Get UFWord
getUFWord = getUShort

-- format 2.14
getUFixed :: Get Double
getUFixed = liftM ((/ 0x4000) . fromIntegral) getShort

data F12Group = F12Group { f12StartCharCode :: ULong
                         , f12EndCharCode :: ULong
                         , f12StartGlyphId :: ULong
                         } deriving (Show)

data CmapTable = CmapFormat0 { c0Format :: UShort
                             , c0Length :: UShort
                             , c0Version :: UShort
                             , c0GlyphIDs :: [Byte]
                             } |
                 CmapFormat4 { c4Format :: UShort
                             , c4Length :: UShort
                             , c4Language :: UShort
                             , c4SegCountX2 :: UShort
                             , c4SearchRange :: UShort
                             , c4EntrySelector :: UShort
                             , c4RangeShift :: UShort
                             , c4EndCodes :: [UShort]
                             , c4ReservedPad :: UShort
                             , c4StartCodes :: [UShort]
                             , c4IdDeltas :: [UShort]
                             , c4IdRangeOffsets :: [UShort]
                             , c4GlyphIds :: [UShort]
                             } |
                 CmapFormat6 { c6Format :: UShort
                             , c6Length :: UShort
                             , c6Version :: UShort
                             , c6FirstCode :: UShort
                             , c6EntryCount :: UShort
                             , c6GlyphIds :: [UShort]
                             } |
                 CmapFormat12 { c12Format :: Fixed
                              , c12Length :: ULong
                              , c12Language :: ULong
                              , c12NGroups :: ULong
                              , c12Groups :: [F12Group]
                              } deriving (Show)


data CmapEncodingDirectory = CmapEncodingDirectory { cmapPlatformId :: UShort
                                                   , cmapEncodingId :: UShort
                                                   , cmapOffset :: ULong
                                                   } deriving (Show)


data Cmap = Cmap { cmapVersion :: UShort
                 , numberOfSubtables :: UShort
                 , encodingDirectories :: [CmapEncodingDirectory]
                 , subTables :: [CmapTable]
                 } deriving (Show)

data TableDirectory = TableDirectory { tag :: String
                                     , checkSum :: ULong
                                     , offset :: ULong
                                     , length :: ULong
                                     , rawData :: B.ByteString
                                     } deriving (Show)


data NameRecord = NameRecord { platformId :: UShort
                               , encodingId :: UShort
                               , languageId :: UShort
                               , nameId :: UShort
                               , strLength :: UShort
                               , strOffset :: UShort
                               , str :: T.Text
                             } deriving (Show)

data Name = Name { formatSelector :: UShort
                   , numberOfNameRecords :: UShort
                   , storageOffset :: UShort
                   , nameRecords :: [NameRecord]
                 } deriving (Show)

data OS2 = OS2 { os2Version :: UShort
               , xAvgCharWidth :: Short
               , usWeightClass :: UShort
               , usWidthClass :: UShort
               , fsType :: UShort
               , ySubscriptXSize :: Short
               , ySubscriptYSize :: Short
               , ySubscriptXOffset :: Short
               , ySubscriptYOffset :: Short
               , ySuperscriptXSize :: Short
               , ySuperscriptYSize :: Short
               , ySuperscriptXOffset :: Short
               , ySuperscriptYOffset :: Short
               , yStrikeoutSize :: Short
               , yStrikeoutPosition :: Short
               , sFamilyClass :: Short
               , panose :: [Byte]
               , ulUnicodeRange1 :: ULong
               , ulUnicodeRange2 :: ULong
               , ulUnicodeRange3 :: ULong
               , ulUnicodeRange4 :: ULong
               , aschVendID :: [Byte]
               , fsSelection :: UShort
               , usFirstCharIndex :: UShort
               , usLastCharIndex :: UShort
               , sTypoAscender :: UShort
               , sTypoDescender :: UShort
               , sTypoLineGap :: UShort
               , usWinAscent :: UShort
               , usWinDescent :: UShort
               , ulCodePageRange1 :: ULong
               , ulCodePageRange2 :: ULong
               } deriving (Show)


data Hhea = Hhea { hheaVersion :: Fixed
                 , ascender :: FWord
                 , descender :: FWord
                 , lineGap :: FWord
                 , advanceWidthMax :: UFWord
                 , minLeftSideBearing :: FWord
                 , minRightSideBearing :: FWord
                 , xMaxExtend :: FWord
                 , caretSlopeRise :: Short
                 , caretSlopeRun :: Short
                   -- reserved 5 Short
                 , metricDataFormat :: Short
                 , numberOfHMetrics :: UShort
                 } deriving (Show)

data Head = Head { headVersion :: Fixed
                 , fontRevision :: Fixed
                 , checkSumAdjusment :: ULong
                 , magicNumber :: ULong
                 , headFlags :: UShort
                 , unitsPerEm :: UShort
                 , created :: B.ByteString
                 , modified :: B.ByteString
                 , xMin :: FWord
                 , yMin :: FWord
                 , xMax :: FWord
                 , yMax :: FWord
                 , macStyle :: UShort
                 , lowestRecPPEM :: UShort
                 , fontDirectionHint :: Short
                 , indexToLocFormat :: Short
                 , glyphDataFormat :: Short
                 } deriving (Show)

data Maxp = Maxp { maxVersion :: Fixed
                 , numGlyphs :: UShort
                 , maxPoints :: UShort
                 , maxContours :: UShort
                 , maxCompositePoints :: UShort
                 , maxCompositeContours :: UShort
                 , maxZones :: UShort
                 , maxTwilightPoints :: UShort
                 , maxStorage :: UShort
                 , maxFunctionDefs :: UShort
                 , maxInstructionDefs :: UShort
                 , maxStackElements :: UShort
                 , maxSizeOfInstructions :: UShort
                 , maxComponentElements :: UShort
                 , maxComponentDepth :: UShort
                 } deriving (Show)



data HMetric = HMetric { advanceWidth :: UFWord
                         , lsb :: FWord
                         } deriving (Show)

data Hmtx = Hmtx { hMetrics :: V.Vector HMetric
                 , leftSideBearings :: [FWord]
                 } deriving (Show)


data Loca = Loca { locaOffsets :: [ULong] } deriving (Show)

data CompositeGlyfElement = CompositeGlyfElement {cFlags :: UShort
                                                 , cGlyphIndex :: UShort
                                                 , cXoffset :: Short
                                                 , cYoffset :: Short
                                                 , cArgument1 :: Short
                                                 , cArgument2 :: Short
                                                 , cXScale :: Double
                                                 , cYScale :: Double
                                                 , cScale01 :: Double
                                                 , cScale10 :: Double
                                                 } deriving (Show)

data Glyf = EmptyGlyf |
            SimpleGlyf { sNumberOfContours :: Short
                         , sXMin :: FWord
                         , sYMin :: FWord
                         , sXMax :: FWord
                         , sYMax :: FWord
                         , sEndPtsOfCountours :: [UShort]
                         , sInstructionLength :: UShort
                         , sInstructions :: [Byte]
                         , sFlags :: [Byte]
                         , sXCoordinates :: [Short]
                         , sYCoordinates :: [Short]
                         } |
            CompositeGlyf { cNumberOfContours :: Short
                          , cXMin :: FWord
                          , cYMin :: FWord
                          , cXMax :: FWord
                          , cYMax :: FWord
                          , cGlyfs :: [CompositeGlyfElement]
                          , cNumInstruction :: UShort
                          , cInstructions :: [Byte]
                          } deriving (Show)

data TTF = TTF { version :: Fixed
               , numTables :: UShort
               , searchRange :: UShort
               , entrySelector :: UShort
               , rangeShift :: UShort
               , tableDirectories :: Map String TableDirectory
               , os2 :: OS2
               , head :: Head
               , hhea :: Hhea
               , name :: Name
               , cmap :: Cmap
               , maxp :: Maxp
               , loca :: Loca
               , hmtx :: Hmtx
               , glyfs :: V.Vector Glyf
               } deriving (Show)


cmapTableFind :: TTF -> UShort -> UShort -> CmapTable
cmapTableFind ttf platformId' encodingId' =
  subTables (cmap ttf) !! index
  where directories = encodingDirectories $ cmap ttf
        index = fromJust $ findIndex predicate directories
        predicate dr = cmapPlatformId dr == platformId' &&
                       cmapEncodingId dr == encodingId'


cmapStart :: CmapTable -> Int
cmapStart CmapFormat0{c0GlyphIDs = glyphIds} = fromJust $ findIndex (> 0) glyphIds
cmapStart CmapFormat4{c4StartCodes = startCodes} = fromIntegral $ minimum startCodes
cmapStart CmapFormat6{c6FirstCode = firstCode} = fromIntegral firstCode
cmapStart CmapFormat12{c12Groups = groups} = fromIntegral $ f12StartCharCode $ Prelude.head groups

cmapEnd :: CmapTable -> Int
cmapEnd CmapFormat0{c0GlyphIDs = glyphIds} = last $ findIndices (> 0) glyphIds
cmapEnd CmapFormat4{c4EndCodes = endCodes} = fromIntegral $ maximum endCodes
cmapEnd CmapFormat6{c6FirstCode = firstCode,
                    c6EntryCount = entryCount} = fromIntegral $ firstCode + entryCount
cmapEnd CmapFormat12{c12Groups = groups} = fromIntegral $ f12EndCharCode $ last groups


glyphId :: CmapTable -> Int -> Int
glyphId CmapFormat0{c0GlyphIDs = glyphIds} n | n >= 0 && n < 256 = fromIntegral $ glyphIds !! n
                                             | otherwise = 0

glyphId CmapFormat4{c4EndCodes = endCodes
                   , c4StartCodes = startCodes
                   , c4IdDeltas = deltas
                   , c4IdRangeOffsets = rangeOffsets
                   , c4GlyphIds = glyphIds
                   , c4SegCountX2 = segCountX2} n'
  | n < 0 || n > 0xFFFF = 0
  | (startCodes !! i) > n = 0
  | (rangeOffsets !! i) == 0 = fromIntegral ((deltas !! i) + n) `mod` 65536
  | otherwise = fromIntegral $ glyphIds !! (fromIntegral $ ((rangeOffsets !! i) `div` 2) + (n - startCodes !! i) - (segCount - fromIntegral i))
  where n = fromIntegral n'
        segCount = segCountX2 `div` 2
        i = fromIntegral . fromJust $ findIndex (>= n) endCodes

glyphId CmapFormat6{c6GlyphIds = glyphIds,
                      c6FirstCode = firstCode,
                      c6EntryCount = entryCount } n | n >= start && n < end = fromIntegral $ glyphIds !! (n - start)
                                                    | otherwise = 0
  where start = fromIntegral firstCode
        end = start + fromIntegral entryCount
glyphId CmapFormat12{c12Groups = groups} n' | start <= n && (not $ start == -1) = glyphId'
                                            | otherwise = 0
  where
    n = fromIntegral n'
    mg = find ((>= n) . f12EndCharCode) groups
    g = fromJust mg
    start = fromMaybe (-1) (liftM f12StartCharCode mg)
    glyphId' = fromIntegral $ (f12StartGlyphId g) + (n - f12StartCharCode g)


parseTableDirectory :: B.ByteString -> Get TableDirectory
parseTableDirectory font = do
  tag <- liftM unpack $ getByteString 4
  checkSum <- getULong
  offset <- getULong
  length <- getULong
  let rawData = substr (fromIntegral offset) (fromIntegral length) font
  return TableDirectory{..}

parseTableDirectories :: B.ByteString -> Int -> Get (Map String TableDirectory)
parseTableDirectories font n = do
  list <- replicateM n $ parseTableDirectory font
  return $ fromList $ map (\x -> (tag x, x)) list

parseNameRecord :: B.ByteString -> Int -> Get NameRecord
parseNameRecord font storageOffset = do
  platformId <- getUShort
  encodingId <- getUShort
  languageId <- getUShort
  nameId <- getUShort
  strLength <- getUShort
  strOffset <- getUShort
  let str = decoder platformId encodingId $ substr
            (fromIntegral ((fromIntegral storageOffset :: Int) + fromIntegral strOffset)) (fromIntegral strLength) font
  return NameRecord{..}
  where
    decoder 3 _ = decodeUtf16BE
    decoder 2 _ = decodeUtf16BE
    decoder 1 _ = decodeUtf8With ignore
    decoder 0 _ = decodeUtf16BE

parseName ::Map String TableDirectory -> B.ByteString -> Name
parseName tableDirectories font =
  getResult $ runGet (do
    let tableStart = fromIntegral $ offset $ tableDirectories ! "name"
    skip tableStart
    formatSelector <- getUShort
    numberOfNameRecords <- getUShort
    storageOffset <- getUShort
    nameRecords <- replicateM (fromIntegral numberOfNameRecords) $ parseNameRecord font (tableStart + fromIntegral storageOffset)
    return Name{..}) font

parseOS2 :: Map String TableDirectory -> B.ByteString -> OS2
parseOS2 = parseTable "OS/2" (do
  os2Version <- getUShort
  unless (os2Version `elem` [1..4]) (error $ "unhandled  os2 version " ++ show os2Version)
  xAvgCharWidth <- getShort
  usWeightClass <- getUShort
  usWidthClass <- getUShort
  fsType <- getUShort
  ySubscriptXSize <- getShort
  ySubscriptYSize <- getShort
  ySubscriptXOffset <- getShort
  ySubscriptYOffset <- getShort
  ySuperscriptXSize <- getShort
  ySuperscriptYSize <- getShort
  ySuperscriptXOffset <- getShort
  ySuperscriptYOffset <- getShort
  yStrikeoutSize <- getShort
  yStrikeoutPosition <- getShort
  sFamilyClass <- getShort
  panose <- replicateM 10 getByte
  ulUnicodeRange1 <- getULong
  ulUnicodeRange2 <- getULong
  ulUnicodeRange3 <- getULong
  ulUnicodeRange4 <- getULong
  aschVendID <- replicateM 4 getByte
  fsSelection <- getUShort
  usFirstCharIndex <- getUShort
  usLastCharIndex <- getUShort
  sTypoAscender <- getUShort
  sTypoDescender <- getUShort
  sTypoLineGap <- getUShort
  usWinAscent <- getUShort
  usWinDescent <- getUShort
  ulCodePageRange1 <- getULong
  ulCodePageRange2 <- getULong
  return OS2 {..})


parseHead :: Map String TableDirectory -> B.ByteString -> Head
parseHead = parseTable "head" (do
  headVersion <- getFixed
  fontRevision <- getFixed
  checkSumAdjusment <- getULong
  magicNumber <- getULong
  headFlags <- getUShort
  unitsPerEm <- getUShort
  created <- getByteString 8
  modified <- getByteString 8
  xMin <- getFWord
  yMin <- getFWord
  xMax <- getFWord
  yMax <- getFWord
  macStyle <- getUShort
  lowestRecPPEM <- getUShort
  fontDirectionHint <- getShort
  indexToLocFormat <- getShort
  glyphDataFormat <- getShort
  return Head{..})

parseHhea :: Map String TableDirectory -> B.ByteString -> Hhea
parseHhea = parseTable "hhea" (do
  hheaVersion <- getFixed
  ascender <- getFWord
  descender <- getFWord
  lineGap <- getFWord
  advanceWidthMax <- getUFWord
  minLeftSideBearing <- getFWord
  minRightSideBearing <- getFWord
  xMaxExtend <- getFWord
  caretSlopeRise <- getShort
  caretSlopeRun <- getShort
  replicateM_ 5 getShort
  metricDataFormat <- getShort
  numberOfHMetrics <- getUShort
  return Hhea{..})

parseMaxp :: Map String TableDirectory -> B.ByteString -> Maxp
parseMaxp = parseTable "maxp" (do
  maxVersion <- getFixed
  numGlyphs <- getUShort
  maxPoints <- getUShort
  maxContours <- getUShort
  maxCompositePoints <- getUShort
  maxCompositeContours <- getUShort
  maxZones <- getUShort
  maxTwilightPoints <- getUShort
  maxStorage <- getUShort
  maxFunctionDefs <- getUShort
  maxInstructionDefs <- getUShort
  maxStackElements <- getUShort
  maxSizeOfInstructions <- getUShort
  maxComponentElements <- getUShort
  maxComponentDepth <- getUShort
  return Maxp{..})

parseHMetric :: Get HMetric
parseHMetric = do
  advanceWidth <- getUFWord
  lsb <- getFWord
  return HMetric{..}

parseHmtx :: Int -> Int -> Map String TableDirectory -> B.ByteString -> Hmtx
parseHmtx mcount glyphCount = parseTable "hmtx" (do
 hMetrics <- liftM V.fromList $ replicateM mcount parseHMetric
 leftSideBearings <- replicateM (glyphCount - mcount) getShort
 return Hmtx{..})



parseFlags :: Int -> [Byte] -> Get [Byte]
parseFlags n a | n <= 0 = return a
               | otherwise = do
  flag <- getByte
  if testBit flag 3 then
    do
     repeats <- liftM fromIntegral getByte
     parseFlags (n - repeats - 1) $ a ++ replicate repeats flag ++ [flag]
    else
    parseFlags (n - 1) $ a ++ [flag]

parseCoordinates ::
  Int -> Int -> (Short, [Short]) -> Byte -> Get (Short, [Short])
parseCoordinates shortBit sameBit (current, ac) flag
  | testBit flag shortBit = do
    delta <- liftM fromIntegral getByte
    return (if testBit flag sameBit then
              (current + delta, ac ++ [current + delta])
            else
              (current - delta, ac ++ [current - delta]))
  | otherwise =
    if testBit flag sameBit then
      return (current, ac ++ [current])
      else
      do
        delta <- getShort
        return (current + delta, ac ++ [current + delta])



parseCompositeGlyfElement :: Get CompositeGlyfElement
parseCompositeGlyfElement = do
  cFlags <- getUShort
  cGlyphIndex <- getUShort
  cArgument1 <- getArg cFlags
  cArgument2 <- getArg cFlags
  let cScale01 = 0.0
      cScale10 = 0.0
      cXScale = 1.0
      cYScale = 1.0
      cXoffset | testBit cFlags args_are_xy_values = cArgument1
               | otherwise = 0
      cYoffset | testBit cFlags args_are_xy_values = cArgument2
               | otherwise = 0
  if testBit cFlags we_have_a_scale then
    do
      cXScale <- liftM fromIntegral getUShort
      let cYScale = cXScale
      return CompositeGlyfElement{..}
    else if testBit cFlags we_have_an_x_and_y_scale then
           do
             cXScale <- getUFixed
             cYScale <- getUFixed
             return CompositeGlyfElement{..}
         else if testBit cFlags we_have_a_two_by_tow then
                do
                  cXScale <- getUFixed
                  cScale01 <- getUFixed
                  cScale10 <- getUFixed
                  cYScale <- getUFixed
                  return CompositeGlyfElement{..}
              else return CompositeGlyfElement{..}
  where getArg f | testBit f arg_1_and_2_are_words = liftM fromIntegral getUShort
                 | otherwise = liftM fromIntegral TTF.getChar
        arg_1_and_2_are_words = 0
        args_are_xy_values = 1
        we_have_a_scale = 3
        we_have_an_x_and_y_scale = 6
        we_have_a_two_by_tow = 7

parseGlyf :: Short -> Get Glyf
parseGlyf numberOfContours | numberOfContours >= 0 = do
  sXMin <- getFWord
  sYMin <- getFWord
  sXMax <- getFWord
  sYMax <- getFWord
  sEndPtsOfCountours <- replicateM (fromIntegral numberOfContours) getUShort
  sInstructionLength <- getUShort
  sInstructions <- replicateM (fromIntegral sInstructionLength) getByte
  let count = if numberOfContours == 0 then 0 else fromIntegral $ last sEndPtsOfCountours + 1
  sFlags <- parseFlags count []
  sXCoordinates <- liftM snd $ foldM (parseCoordinates 1 4) (0, []) sFlags
  sYCoordinates <- liftM snd $ foldM (parseCoordinates 2 5) (0, []) sFlags
  return SimpleGlyf{sNumberOfContours = numberOfContours, ..}
                           | otherwise = do
  cXMin <- getFWord
  cYMin <- getFWord
  cXMax <- getFWord
  cYMax <- getFWord
  cGlyfs <- parseElements
  let lastFlag = cFlags $ last cGlyfs
      cNumInstruction = 0
      cInstructions = []
  if testBit lastFlag we_have_instructions then
    do
      cNumInstruction <- getUShort
      cInstructions <- replicateM (fromIntegral cNumInstruction) getByte
      return CompositeGlyf{cNumberOfContours = numberOfContours, ..}
    else return CompositeGlyf{cNumberOfContours = numberOfContours, ..}
  where
    parseElements = do
          cge <- parseCompositeGlyfElement
          if testBit (cFlags cge) more_components then
            do
              rest <- parseElements
              return $ cge : rest
            else
            return [cge]
    more_components = 5
    we_have_instructions = 8



parseGlyfs :: Int -> [Int] -> Map String TableDirectory -> B.ByteString -> [Glyf]
parseGlyfs glyphCount offsets tableDirectories font =
  zipWith getGlyph (take glyphCount offsets) $ diff offsets
  where tableStart = fromIntegral . offset $ tableDirectories ! "glyf"
        getGlyph _ 0 = EmptyGlyf
        getGlyph offset _len =
          getResult $ runGet (do
            skip $ tableStart + offset
            numberOfContours <- getShort
            parseGlyf numberOfContours
          ) font

parseLoca :: Int -> Int -> Map String TableDirectory -> B.ByteString -> Loca
parseLoca 0 count = parseTable "loca" (do
  locaOffsets <- replicateM (count + 1) (liftM ((*) 2 . fromIntegral) getUShort)
  return Loca{..})
parseLoca 1 count = parseTable "loca" (do
  locaOffsets <- replicateM (count + 1) getULong
  return Loca{..})

parseCmapEncodingDirectory :: Get CmapEncodingDirectory
parseCmapEncodingDirectory = do
  cmapPlatformId <- getUShort
  cmapEncodingId <- getUShort
  cmapOffset <- getULong
  return CmapEncodingDirectory{..}


parseCmapSubTable :: Int -> Get CmapTable
parseCmapSubTable 4 = do
  c4Length <- getUShort
  c4Language <- getUShort
  c4SegCountX2 <- getUShort
  let segCount = fromIntegral c4SegCountX2 `div` 2
  c4SearchRange <- getUShort
  c4EntrySelector <- getUShort
  c4RangeShift <- getUShort
  c4EndCodes <- replicateM segCount getUShort
  c4ReservedPad <- getUShort
  c4StartCodes <- replicateM segCount getUShort
  c4IdDeltas <- replicateM segCount getUShort
  c4IdRangeOffsets <- replicateM segCount getUShort
  let glyphCount = (fromIntegral c4Length - (2 * 8) - (2 * segCount * 4)) `div` 2
  c4GlyphIds <- replicateM glyphCount getUShort
  return CmapFormat4{c4Format = 4, ..}

parseCmapSubTable 0 = do
  c0Length <- getUShort
  c0Version <- getUShort
  c0GlyphIDs <- replicateM 256 getByte
  return CmapFormat0{c0Format = 0, ..}

parseCmapSubTable 6 = do
  c6Length <- getUShort
  c6Version <- getUShort
  c6FirstCode <- getUShort
  c6EntryCount <- getUShort
  c6GlyphIds <- replicateM (fromIntegral c6EntryCount) getUShort
  return CmapFormat6{c6Format = 6, ..}

parseCmapSubTable 12 = do
  _ <- getUShort
  c12Length <- getULong
  c12Language <- getULong
  c12NGroups <- getULong
  c12Groups <- replicateM (fromIntegral c12NGroups) parseF12Group
  return CmapFormat12{c12Format = 12, ..}
  where parseF12Group = do
          f12StartCharCode <- getULong
          f12EndCharCode <- getULong
          f12StartGlyphId <- getULong
          return F12Group{..}

parseCmapSubTable n = error $ "subtable format not implemented " ++ show n

parseCmapEncoding :: B.ByteString -> Int -> CmapTable
parseCmapEncoding font offset =
  getResult $ runGet (do
   skip offset
   format <- getUShort
   parseCmapSubTable $ fromIntegral format) font

parseCmap :: Map String TableDirectory -> B.ByteString -> Cmap
parseCmap tableDirectories font =
  getResult $ runGet (do
    let tableStart = fromIntegral $ offset $ tableDirectories ! "cmap"
    skip tableStart
    cmapVersion <- getUShort
    numberOfSubtables <- getUShort
    encodingDirectories <- replicateM (fromIntegral numberOfSubtables) parseCmapEncodingDirectory
    let subTables = map (parseCmapEncoding font . (+ tableStart) . fromIntegral . cmapOffset) encodingDirectories
    return Cmap{..}) font

parseTable :: String -> Get a -> Map String TableDirectory -> B.ByteString -> a
parseTable name m tableDirectories font =
  getResult $ runGet (do
    skip $ fromIntegral . offset $ tableDirectories ! name
    m) font

parse :: B.ByteString -> Get TTF
parse font = do
  version <- getFixed
  numTables <- getUShort
  searchRange <- getUShort
  entrySelector <- getUShort
  rangeShift <- getUShort
  tableDirectories <- parseTableDirectories font (fromIntegral numTables)
  let os2 = parseOS2 tableDirectories font
      head = parseHead tableDirectories font
      hhea = parseHhea tableDirectories font
      name = parseName tableDirectories font
      cmap = parseCmap tableDirectories font
      maxp = parseMaxp tableDirectories font
      glyphCount = (fromIntegral $ numGlyphs maxp)
      loca = parseLoca (fromIntegral $ indexToLocFormat head) glyphCount tableDirectories font
      hmtx = parseHmtx (fromIntegral $ numberOfHMetrics hhea) glyphCount tableDirectories font
      glyfs = V.fromList $ parseGlyfs glyphCount (map fromIntegral $ locaOffsets loca) tableDirectories font
    in
    return TTF{..}
