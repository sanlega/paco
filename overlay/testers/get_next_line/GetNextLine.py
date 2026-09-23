import logging
import shutil
from testers.BaseTester import BaseTester
from testers.get_next_line.Fsoares import Fsoares

from testers.get_next_line.Tripouille import Tripouille
from utils.ExecutionContext import TestRunInfo, set_bonus
from utils.Utils import show_banner

logger = logging.getLogger("gnl")

# Campus rule: the bonus part of get_next_line is now mandatory, so students
# no longer split it into "*_bonus" files - everything lives in the normal
# get_next_line.c / get_next_line.h / get_next_line_utils.c files. The
# upstream test harnesses (fsoares, and the vendored Tripouille gnlTester)
# still look for the historical "*_bonus" filenames, so instead of patching
# that third-party code we alias the mandatory files onto those names once
# the source has been copied into the working directory.
BONUS_ALIASES = {
	"get_next_line.c": "get_next_line_bonus.c",
	"get_next_line.h": "get_next_line_bonus.h",
	"get_next_line_utils.c": "get_next_line_utils_bonus.c",
}


class GetNextLine(BaseTester):

	name = "get_next_line"
	my_tester = Fsoares
	testers = [Tripouille, Fsoares]
	timeout = 10

	def __init__(self, info: TestRunInfo) -> None:
		super().__init__(info)
		self.execute_testers()

	def select_tests_to_execute(self):
		if not self.info.args.mandatory:
			logger.info("Bonus is mandatory, testing it along with the mandatory part")
			set_bonus(True)
			self._alias_bonus_files()
		return []

	def _alias_bonus_files(self):
		for mandatory_name, bonus_name in BONUS_ALIASES.items():
			mandatory_file = self.temp_dir / mandatory_name
			bonus_file = self.temp_dir / bonus_name
			if mandatory_file.exists() and not bonus_file.exists():
				logger.info(f"Aliasing {mandatory_file} as {bonus_file}")
				shutil.copyfile(mandatory_file, bonus_file)

	@staticmethod
	def is_project(current_path):
		file_path = current_path / 'get_next_line.c'
		logger.info(f"Testing: {file_path}")
		if not file_path.exists():
			return False
		return GetNextLine
