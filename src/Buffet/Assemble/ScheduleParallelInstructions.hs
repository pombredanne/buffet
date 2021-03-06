module Buffet.Assemble.ScheduleParallelInstructions
  ( get
  ) where

import qualified Buffet.Assemble.JoinConsecutiveEnvInstructions as JoinConsecutiveEnvInstructions
import qualified Buffet.Assemble.JoinConsecutiveRunInstructions as JoinConsecutiveRunInstructions
import qualified Buffet.Ir.Ir as Ir
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as T
import qualified Language.Docker as Docker
import Prelude
  ( Bool(False, True)
  , Maybe(Just, Nothing)
  , ($)
  , (.)
  , (/=)
  , (<>)
  , (==)
  , all
  , concatMap
  , dropWhile
  , filter
  , fmap
  , mconcat
  , minimum
  , null
  , span
  , splitAt
  , take
  , unzip
  )

type ScheduleStep
   = [Ir.DockerfilePart] -> (Ir.DockerfilePart, [Ir.DockerfilePart])

get :: [Ir.DockerfilePart] -> [Ir.DockerfilePart]
get = wrap . schedule []
  where
    wrap [] = []
    wrap timetable = [timetable]
    schedule timetable queues =
      if all null queues
        then timetable
        else schedule timetable' queues'
      where
        timetable' = timetable <> step
        (step, queues') = scheduleStep queues

scheduleStep :: ScheduleStep
scheduleStep queues =
  case filter (\(_, queues') -> queues' /= queues) results of
    [] -> ([], queues)
    result:_ -> result
  where
    results = fmap ($ queues) strategies
    strategies =
      [ scheduleFromInstructions
      , scheduleArgInstructions
      , scheduleShellInstructions
      , scheduleCopyInstructions
      , scheduleEnvInstructions
      , scheduleRunInstructions
      , scheduleWorkdirInstructions
      , scheduleCommentInstructions
      , scheduleNextInstructionEach
      ]

scheduleFromInstructions :: ScheduleStep
scheduleFromInstructions = unifyInstructions isFrom
  where
    isFrom (Docker.From _) = True
    isFrom _ = False

unifyInstructions :: (Docker.Instruction T.Text -> Bool) -> ScheduleStep
unifyInstructions isRelevant queues =
  case minimumInstruction of
    Nothing -> ([], queues)
    Just instruction ->
      ([instruction], fmap (dropWhile (== instruction)) queues)
  where
    minimumInstruction =
      fmap minimum . NonEmpty.nonEmpty $ nextInstructionsIfRelevant
    nextInstructionsIfRelevant = concatMap (filter isRelevant . take 1) queues

scheduleArgInstructions :: ScheduleStep
scheduleArgInstructions = unifyInstructions isArg
  where
    isArg (Docker.Arg _ _) = True
    isArg _ = False

scheduleShellInstructions :: ScheduleStep
scheduleShellInstructions = unifyInstructions isShell
  where
    isShell (Docker.Shell _) = True
    isShell _ = False

scheduleCopyInstructions :: ScheduleStep
scheduleCopyInstructions = spanInstructions isCopy
  where
    isCopy (Docker.Copy _) = True
    isCopy _ = False

spanInstructions :: (Docker.Instruction T.Text -> Bool) -> ScheduleStep
spanInstructions isRelevant queues = (mconcat spans, queues')
  where
    (spans, queues') = unzip $ fmap (span isRelevant) queues

scheduleEnvInstructions :: ScheduleStep
scheduleEnvInstructions queues =
  (JoinConsecutiveEnvInstructions.get envs, queues')
  where
    (envs, queues') = spanInstructions isEnv queues
    isEnv (Docker.Env _) = True
    isEnv _ = False

scheduleRunInstructions :: ScheduleStep
scheduleRunInstructions queues =
  (JoinConsecutiveRunInstructions.get runs, queues')
  where
    (runs, queues') = spanInstructions isRun queues
    isRun (Docker.Run _) = True
    isRun _ = False

scheduleWorkdirInstructions :: ScheduleStep
scheduleWorkdirInstructions = unifyInstructions isWorkdir
  where
    isWorkdir (Docker.Workdir _) = True
    isWorkdir _ = False

scheduleCommentInstructions :: ScheduleStep
scheduleCommentInstructions = unifyInstructions isComment
  where
    isComment (Docker.Comment _) = True
    isComment _ = False

scheduleNextInstructionEach :: ScheduleStep
scheduleNextInstructionEach queues = (mconcat nexts, queues')
  where
    (nexts, queues') = unzip $ fmap (splitAt 1) queues
