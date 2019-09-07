module Buffet.Build.ArgInstructions
  ( get
  ) where

import qualified Buffet.Ir.Ir as Ir
import qualified Buffet.Ir.IrTools as IrTools
import qualified Data.List as List
import qualified Data.Text as T
import qualified Language.Docker as Docker hiding (sourcePaths)
import Prelude (Bool(False), Maybe(Just), ($), (.), (/=), (<>), concat, filter)

get :: Ir.Buffet -> [Ir.DockerfilePart]
get buffet = [List.sort $ mainOptions <> baseImageOptions]
  where
    mainOptions = concat $ IrTools.mapOrderedEntries dishArgInstructions buffet
    baseImageOptions :: [Docker.Instruction a]
    baseImageOptions =
      [Docker.Arg (T.pack "alpine_version") . Just $ T.pack "'3.9.4'"]

dishArgInstructions :: T.Text -> Ir.Dish -> Ir.DockerfilePart
dishArgInstructions option dish =
  Docker.Arg option (Just $ T.pack "''") : extraOptions
  where
    extraOptions = filter isExtraOption $ Ir.beforeFirstBuildStage dish
    isExtraOption :: Docker.Instruction a -> Bool
    isExtraOption (Docker.Arg key _) = key /= option
    isExtraOption _ = False