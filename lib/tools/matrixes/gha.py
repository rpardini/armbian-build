def wrap_with_gha_expression(value):
	return "${{ " + value + " }}"


class WorkflowJobCondition:
	def __init__(self, condition):
		self.condition = condition


# Warning: there are no real "job inputs" in GHA. this is just an abstraction to make it easier to work with
class WorkflowJobInput:
	def __init__(self, value: str):
		self.value = value
		# The Job that holds this input
		self.job: BaseWorkflowJob | None = None


class WorkflowJobOutput:
	def __init__(self, name: str, value: str):
		self.name = name
		self.value = value
		# The Job that produces this output
		self.job: BaseWorkflowJob | None = None
		# The step that produces this output (optional)
		self.step: WorkflowJobStep | None = None

	def render_yaml(self):
		return wrap_with_gha_expression(f"{self.value}")


class WorkflowJobStep:
	def __init__(self, id: str, name: str):
		self.id = id
		self.name = name
		self.run: "str | None" = None

	def render_yaml(self):
		return {"id": self.id, "name": self.name, "run": self.run}


class BaseWorkflowJob:
	def __init__(self, job_id: str, job_name: str):
		self.job_id: str = job_id
		self.job_name: str = job_name
		self.outputs: dict[str, WorkflowJobOutput] = {}
		self.needs: set[BaseWorkflowJob] = set()
		self.conditions: list[WorkflowJobCondition] = []
		self.steps: list[WorkflowJobStep] = []

	def add_step(self, step_id: str, step_name: str):
		step = WorkflowJobStep(step_id, step_name)
		self.steps.append(step)
		return step

	def add_job_output_from_step(self, step: WorkflowJobStep, output_name: str) -> WorkflowJobOutput:
		job_wide_name = f"{step.id}_{output_name}"
		output = WorkflowJobOutput(job_wide_name, f"steps.{step.id}.outputs.{output_name}")
		output.step = step
		output.job = self
		self.outputs[job_wide_name] = output
		return output

	def add_job_output_from_input(self, name: str, input: WorkflowJobInput) -> WorkflowJobOutput:
		output = WorkflowJobOutput(name, input.value)
		output.job = self
		self.outputs[name] = output
		return output

	def add_job_input_from_needed_job_output(self, job_output: WorkflowJobOutput):
		# add referenced job as a 'needs' dependency, so we can read it.
		self.needs.add(job_output.job)
		input = WorkflowJobInput(f"needs.{job_output.job.job_id}.outputs.{job_output.name}")
		input.job = self
		return input

	def add_condition_from_input(self, input: WorkflowJobInput, expression: str):
		condition = WorkflowJobCondition(f"{input.value} {expression}")
		self.conditions.append(condition)
		return condition

	def render_yaml(self) -> dict[str, object]:
		job: dict[str, object] = {}
		job["name"] = self.job_name
		if len(self.needs) > 0:
			job["needs"] = [n.job_id for n in self.needs]

		if len(self.conditions) > 0:
			conds: list[str] = []
			conds.append("always()")  # only if asked for...
			for cond in self.conditions:
				conds.append(cond.condition)
			# @TODO: this is so naive it hurts
			job["if"] = wrap_with_gha_expression(" && ".join([c for c in conds]))

		if len(self.outputs) > 0:
			job["outputs"] = {o.name: o.render_yaml() for o in self.outputs.values()}

		job["runs-on"] = ["self-hosted", "Linux", "armbian"]

		if len(self.steps) > 0:
			job["steps"] = [s.render_yaml() for s in self.steps]
		else:
			raise Exception("No steps defined for job")

		return job


class WorkflowFactory:
	def __init__(self):
		self.jobs: dict[str, BaseWorkflowJob] = {}

	def add_job(self, job: BaseWorkflowJob) -> BaseWorkflowJob:
		if job.job_id in self.jobs:
			raise Exception(f"Double adding of job {job.job_id}")
		self.jobs[job.job_id] = job
		return job

	def get_job(self, job_id: str) -> BaseWorkflowJob:
		if job_id not in self.jobs:
			raise Exception(f"Job {job_id} not found")
		return self.jobs[job_id]

	def render_yaml(self) -> dict[str, object]:
		gha_workflow: dict[str, object] = dict()
		gha_workflow["name"] = "fake"
		gha_workflow["on"] = {"workflow_dispatch": {"inputs": {"name": {"description": "Name", "required": True, "default": "World"}}}}

		jobs = {}  # @TODO: maybe sort... maybe prepare...
		for job in self.jobs.values():
			jobs[job.job_id] = job.render_yaml()

		gha_workflow["jobs"] = jobs
		return gha_workflow
